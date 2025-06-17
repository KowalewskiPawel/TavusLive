//
//  SensorManager.swift
//  TavusLive
//
//  Created by Pawel Kowalewski on 16/06/2025.
//

import Foundation
import CoreMotion
import Combine

class SensorManager: ObservableObject {
    private let motionManager = CMMotionManager()
    private let operationQueue = OperationQueue()
    
    @Published var isMonitoring = false
    @Published var lastSensorEvent: String?
    
    // Callbacks for different sensor events
    var onDeviceDropped: (() -> Void)?
    var onDeviceShaken: (() -> Void)?
    var onDeviceFlipped: (() -> Void)?
    var onDeviceTilted: ((String) -> Void)?
    var onDoubleShake: (() -> Void)?      // New: For interrupt trigger
    var onHardShake: (() -> Void)?        // New: For strong interrupt
    
    // Thresholds for different events
    private let dropThreshold: Double = 2.5  // G-force threshold for detecting drops
    private let shakeThreshold: Double = 3.0 // G-force threshold for detecting shakes
    private let hardShakeThreshold: Double = 5.0 // Higher threshold for interrupt shakes
    private var lastAcceleration: CMAcceleration?
    private var shakeDetectionTimer: Timer?
    private var shakeCount = 0
    private var shakeTimestamp: Date?
    
    init() {
        setupMotionManager()
    }
    
    private func setupMotionManager() {
        guard motionManager.isAccelerometerAvailable else {
            print("Accelerometer not available")
            return
        }
        
        motionManager.accelerometerUpdateInterval = 0.1 // 10Hz updates
        operationQueue.maxConcurrentOperationCount = 1
    }
    
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        motionManager.startAccelerometerUpdates(to: operationQueue) { [weak self] (data, error) in
            guard let self = self, let accelerometerData = data else { return }
            
            self.processAccelerometerData(accelerometerData)
        }
        
        // Also monitor device motion for orientation changes
        if motionManager.isDeviceMotionAvailable {
            motionManager.startDeviceMotionUpdates(to: operationQueue) { [weak self] (motion, error) in
                guard let self = self, let deviceMotion = motion else { return }
                
                self.processDeviceMotion(deviceMotion)
            }
        }
        
        DispatchQueue.main.async {
            self.isMonitoring = true
        }
        print("Started sensor monitoring")
    }
    
    func stopMonitoring() {
        motionManager.stopAccelerometerUpdates()
        motionManager.stopDeviceMotionUpdates()
        DispatchQueue.main.async {
            self.isMonitoring = false
        }
        print("Stopped sensor monitoring")
    }
    
    private func processAccelerometerData(_ data: CMAccelerometerData) {
        let acceleration = data.acceleration
        let totalAcceleration = sqrt(pow(acceleration.x, 2) + pow(acceleration.y, 2) + pow(acceleration.z, 2))
        
        // Detect sudden drops (low G-force)
        if totalAcceleration < 0.1 {
            detectDrop()
        }
        
        // Detect shaking (high G-force changes)
        if let lastAccel = lastAcceleration {
            let deltaX = abs(acceleration.x - lastAccel.x)
            let deltaY = abs(acceleration.y - lastAccel.y)
            let deltaZ = abs(acceleration.z - lastAccel.z)
            let totalDelta = deltaX + deltaY + deltaZ
            
            if totalDelta > hardShakeThreshold {
                detectHardShake()
            } else if totalDelta > shakeThreshold {
                detectShake()
            }
        }
        
        lastAcceleration = acceleration
    }
    
    private func processDeviceMotion(_ motion: CMDeviceMotion) {
        let attitude = motion.attitude
        let pitch = attitude.pitch * 180.0 / .pi
        let roll = attitude.roll * 180.0 / .pi
        
        // Detect device flip (upside down)
        if abs(roll) > 160 || abs(pitch) > 160 {
            detectFlip()
        }
        
        // Detect significant tilting
        if abs(pitch) > 45 || abs(roll) > 45 {
            let direction = determineDirection(pitch: pitch, roll: roll)
            onDeviceTilted?(direction)
        }
    }
    
    private func detectDrop() {
        DispatchQueue.main.async {
            self.lastSensorEvent = "Device dropped!"
        }
        print("🫳 Device drop detected!")
        onDeviceDropped?()
    }
    
    private func detectShake() {
        let now = Date()
        
        // Check for double shake (two shakes within 1 second)
        if let lastShake = shakeTimestamp, now.timeIntervalSince(lastShake) < 1.0 {
            shakeCount += 1
            if shakeCount >= 2 {
                detectDoubleShake()
                shakeCount = 0
                shakeTimestamp = nil
                return
            }
        } else {
            shakeCount = 1
            shakeTimestamp = now
        }
        
        // Debounce regular shake detection
        shakeDetectionTimer?.invalidate()
        shakeDetectionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            if self.shakeCount == 1 {
                DispatchQueue.main.async {
                    self.lastSensorEvent = "Device shaken!"
                }
                print("📳 Device shake detected!")
                self.onDeviceShaken?()
            }
            self.shakeCount = 0
            self.shakeTimestamp = nil
        }
    }
    
    private func detectDoubleShake() {
        DispatchQueue.main.async {
            self.lastSensorEvent = "Device double-shaken!"
        }
        print("📳📳 Double shake detected! (Interrupt trigger)")
        onDoubleShake?()
    }
    
    private func detectHardShake() {
        DispatchQueue.main.async {
            self.lastSensorEvent = "Device hard-shaken!"
        }
        print("📳💥 Hard shake detected! (Strong interrupt)")
        onHardShake?()
    }
    
    private func detectFlip() {
        DispatchQueue.main.async {
            self.lastSensorEvent = "Device flipped!"
        }
        print("🔄 Device flip detected!")
        onDeviceFlipped?()
    }
    
    private func determineDirection(pitch: Double, roll: Double) -> String {
        if pitch > 45 { return "tilted forward" }
        if pitch < -45 { return "tilted backward" }
        if roll > 45 { return "tilted right" }
        if roll < -45 { return "tilted left" }
        return "tilted"
    }
    
    deinit {
        stopMonitoring()
    }
}
