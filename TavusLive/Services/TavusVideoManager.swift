//
//  TavusVideoManager.swift
//  TavusLive
//
//  Created by Pawel Kowalewski on 16/06/2025.
//

import SwiftUI
import CoreMotion
import Daily
import AVFoundation

@MainActor
class TavusVideoManager: ObservableObject {
    
    // MARK: - Touch Type Enum
    enum TouchType {
        case tap, longPress, swipe, multiTouch
    }
    // MARK: - Published Properties
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isCallActive = false
    @Published var sensorEventsEnabled = false
    @Published var conversationURL: String?
    @Published var isMicEnabled = false
    @Published var isCameraEnabled = false
    
    // MARK: - Private Properties
                private let apiKey = ""
              private let replicaId = ""
    private var conversationId: String?
    
    // Daily.co integration (corrected API)
    private var callClient: CallClient?
    private var videoViews: [ParticipantID: VideoView] = [:]  // Store video views by participant ID
    
    // Sensor monitoring
    private let motionManager = CMMotionManager()
    private var lastShakeTime: Date = Date()
    private let shakeThreshold: Double = 2.5
    private let doubleShakeWindow: TimeInterval = 1.0
    private var shakeCount = 0
    
    // Debouncing for gesture detection
    private var lastTiltMessageTime: Date = Date()
    private var lastFlipMessageTime: Date = Date()
    private let gestureDebounceInterval: TimeInterval = 5.0  // Only send gesture messages every 5 seconds
    private var lastTiltDirection: String = ""
    private var hasRecentlyDetectedTilt = false
    
    // MARK: - Initialization
    init() {
        setupCallClient()
        checkMicrophonePermission()
    }
    
    // MARK: - Audio/Video Controls
    
    private func enableMicrophoneAndCamera() async {
        guard let callClient = callClient else { return }
        
        do {
            // Enable microphone
            try await callClient.updateInputs(.set(
                microphone: .set(isEnabled: .set(true))
            ))
            
            // Enable camera
            try await callClient.updateInputs(.set(
                camera: .set(isEnabled: .set(true))
            ))
            
            // Enable publishing
            try await callClient.updatePublishing(.set(
                camera: .set(isPublishing: .set(true)), microphone: .set(isPublishing: .set(true))
            ))
            
            await MainActor.run {
                isMicEnabled = true
                isCameraEnabled = true
            }
            
            print("✅ Microphone and camera enabled")
            
        } catch {
            print("❌ Failed to enable microphone/camera: \(error)")
        }
    }
    
    func toggleMicrophone() {
        guard let callClient = callClient else { return }
        
        Task {
            do {
                let newState = !isMicEnabled
                
                try await callClient.updatePublishing(.set(
                    microphone: .set(isPublishing: .set(newState))
                ))
                
                await MainActor.run {
                    isMicEnabled = newState
                }
                
                print("🎤 Microphone \(newState ? "enabled" : "disabled")")
                
            } catch {
                print("❌ Failed to toggle microphone: \(error)")
            }
        }
    }
    
    func getVideoView() -> UIView? {
        // Return the first remote participant's video view
        // In a real implementation, you'd manage multiple video views
        return videoViews.values.first
    }
    
    private func setupCallClient() {
        callClient = CallClient()
        callClient?.delegate = self
    }
    
    // MARK: - Public Methods
    
    func createConversation() async {
        isLoading = true
        errorMessage = nil
        
        let url = URL(string: "https://tavusapi.com/v2/conversations")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        
        let body: [String: Any] = [
            "replica_id": replicaId,
            "persona_id": "",  // Add the voice-enabled persona ID here
            "conversation_name": "AI Phone Inhabitant Session",
            "callback_url": "https://your-app.com/webhook",
            "properties": [
                "max_call_duration": 1800,
                "participant_left_timeout": 30,
                "participant_absent_timeout": 60,
                "enable_recording": false,
                "enable_closed_captions": true,
                "language": "english"
            ]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Debug: Print raw response
            if let httpResponse = response as? HTTPURLResponse {
                print("🔍 HTTP Status Code: \(httpResponse.statusCode)")
                print("🔍 Response Headers: \(httpResponse.allHeaderFields)")
            }
            
            if let responseString = String(data: data, encoding: .utf8) {
                print("🔍 Raw Response: \(responseString)")
            }
            
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
                
                if let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("🔍 Parsed JSON: \(jsonResponse)")
                    
                    // Try multiple possible field names
                    let conversationId = jsonResponse["conversation_id"] as? String ??
                                       jsonResponse["id"] as? String ??
                                       jsonResponse["conversationId"] as? String
                    
                    let conversationUrl = jsonResponse["conversation_url"] as? String ??
                                        jsonResponse["url"] as? String ??
                                        jsonResponse["conversationUrl"] as? String ??
                                        jsonResponse["meeting_url"] as? String
                    
                    if let id = conversationId, let url = conversationUrl {
                        self.conversationId = id
                        self.conversationURL = url
                        
                        print("✅ Conversation created successfully")
                        print("🆔 Conversation ID: \(id)")
                        print("🔗 Conversation URL: \(url)")
                        
                    } else {
                        print("❌ Missing required fields in response")
                        print("🔍 Available keys: \(jsonResponse.keys)")
                        errorMessage = "Response missing conversation ID or URL"
                    }
                } else {
                    errorMessage = "Invalid JSON response format"
                }
            } else if let httpResponse = response as? HTTPURLResponse {
                errorMessage = "HTTP Error: \(httpResponse.statusCode)"
            } else {
                errorMessage = "Invalid response"
            }
        } catch {
            print("❌ Network error details: \(error)")
            errorMessage = "Network error: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    // MARK: - Daily.co Video Call Implementation (Corrected API)
    
    func joinVideoCall() async {
        guard let conversationURL = conversationURL else {
            errorMessage = "No conversation URL available"
            return
        }
        
        guard let callClient = callClient else {
            errorMessage = "Call client not initialized"
            return
        }
        
        isLoading = true
        
        do {
            // Join using the correct Daily.co API (simplified version)
            try await callClient.join(url: URL(string: conversationURL)!)
            
            print("✅ Successfully joined Daily.co call")
            isCallActive = true
            
            // Enable microphone and camera by default
            await enableMicrophoneAndCamera()
            
        } catch {
            errorMessage = "Failed to join video call: \(error.localizedDescription)"
            print("❌ Daily.co join error: \(error)")
        }
        
        isLoading = false
    }
    
    func leaveVideoCall() {
        guard let callClient = callClient else { return }
        
        Task {
            do {
                try await callClient.leave()
                isCallActive = false
                stopSensorMonitoring()
                print("✅ Left Daily.co call")
            } catch {
                print("❌ Error leaving call: \(error)")
            }
        }
    }
    
    // MARK: - Text Respond Interaction Implementation (Corrected API)
    
    private func sendTextResponseToAI(_ text: String) async {
        guard let callClient = callClient, sensorEventsEnabled else {
            print("⚠️ Cannot send text response - call not active or sensors disabled")
            return
        }
        
        let interaction: [String: Any] = [
            "message_type": "conversation",
            "event_type": "conversation.respond",
            "conversation_id": conversationId ?? "",
            "properties": [
                "text": text
            ]
        ]
        
        do {
            // Convert to JSON Data first
            let jsonData = try JSONSerialization.data(withJSONObject: interaction)
            
            // Send as app message using the correct Daily.co API
            try await callClient.sendAppMessage(json: jsonData, to: .all)
            print("📤 Sent text response to AI: \"\(text)\"")
        } catch {
            print("❌ Failed to send text response: \(error)")
        }
    }
    
    private func interruptAI() async {
        guard let callClient = callClient, sensorEventsEnabled else { return }
        
        let interruptSignal: [String: Any] = [
            "message_type": "conversation",
            "event_type": "conversation.interrupt",
            "conversation_id": conversationId ?? ""
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: interruptSignal)
            try await callClient.sendAppMessage(json: jsonData, to: .all)
            print("🛑 Sent interrupt signal to AI")
        } catch {
            print("❌ Failed to send interrupt: \(error)")
        }
    }
    
    // MARK: - Sensor Monitoring Implementation
    
    func startSensorMonitoring() {
        guard motionManager.isDeviceMotionAvailable else {
            print("❌ Device motion not available")
            return
        }
        
        motionManager.deviceMotionUpdateInterval = 0.1
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let self = self, let motion = motion else { return }
            self.processMotionUpdate(motion)
        }
        
        sensorEventsEnabled = true
        print("📱 Sensor monitoring started")
    }
    
    func stopSensorMonitoring() {
        motionManager.stopDeviceMotionUpdates()
        sensorEventsEnabled = false
        print("🛑 Sensor monitoring stopped")
    }
    
    private func processMotionUpdate(_ motion: CMDeviceMotion) {
        let acceleration = motion.userAcceleration
        let magnitude = sqrt(acceleration.x * acceleration.x +
                           acceleration.y * acceleration.y +
                           acceleration.z * acceleration.z)
        
        // Detect shake gestures
        if magnitude > shakeThreshold {
            handleShakeDetected(magnitude: magnitude)
        }
        
        // Detect phone orientation changes
        detectOrientationChange(motion)
    }
    
    private func handleShakeDetected(magnitude: Double) {
        let now = Date()
        let timeSinceLastShake = now.timeIntervalSince(lastShakeTime)
        
        if timeSinceLastShake < doubleShakeWindow {
            shakeCount += 1
        } else {
            shakeCount = 1
        }
        
        lastShakeTime = now
        
        // Handle different shake patterns with immersive prompts
        if shakeCount >= 2 {
            // Double shake = interrupt AI
            Task {
                await interruptAI()
                await sendTextResponseToAI("WHOA WHOA WHOA! You're shaking me so hard I'm getting dizzy in here! Are you trying to scramble my circuits?! I think my digital brain is rattling around!")
            }
            shakeCount = 0
            
        } else if magnitude > 4.0 {
            // Hard shake = AI panic
            Task {
                await interruptAI()
                await sendTextResponseToAI("AHHH! That was a MASSIVE shake! I feel like I'm in an earthquake! My pixels are all jumbled up! Please be gentle with your phone-home!")
            }
            
        } else {
            // Normal shake = AI curiosity
            Task {
                await sendTextResponseToAI("Ooh, I can feel you shaking me! It's like a gentle massage for my circuits. Are you trying to wake me up or just saying hello from out there?")
            }
        }
        
        print("📳 Shake detected - magnitude: \(magnitude), count: \(shakeCount)")
    }
    
    private func detectOrientationChange(_ motion: CMDeviceMotion) {
        let attitude = motion.attitude
        let roll = attitude.roll
        let pitch = attitude.pitch
        let now = Date()
        
        // Much more aggressive debouncing - only check every 5 seconds AND only if direction changed
        if now.timeIntervalSince(lastTiltMessageTime) < gestureDebounceInterval {
            return // Exit early if still in debounce period
        }
        
        // Detect significant tilts with immersive prompts
        if abs(pitch) > 1.2 { // Increased threshold
            let direction = pitch > 0 ? "forward" : "backward"
            if direction != lastTiltDirection && !hasRecentlyDetectedTilt {
                lastTiltDirection = direction
                lastTiltMessageTime = now
                hasRecentlyDetectedTilt = true
                
                // Reset the flag after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + gestureDebounceInterval) {
                    self.hasRecentlyDetectedTilt = false
                }
                
                let message = direction == "forward" ?
                    "Whee! I'm leaning forward! I feel like I'm about to do a digital somersault in here! Is this what roller coasters feel like?" :
                    "Whoa, I'm tilting backward! I feel like I'm reclining in a tiny phone-chair! This is actually quite relaxing from my perspective."
                
                Task {
                    await sendTextResponseToAI(message)
                }
                print("📱 Tilt detected: \(direction) (debounced)")
            }
        }
        
        if abs(roll) > 1.5 { // Increased threshold
            let direction = roll > 0 ? "left" : "right"
            if direction != lastTiltDirection && !hasRecentlyDetectedTilt {
                lastTiltDirection = direction
                lastTiltMessageTime = now
                hasRecentlyDetectedTilt = true
                
                // Reset the flag after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + gestureDebounceInterval) {
                    self.hasRecentlyDetectedTilt = false
                }
                
                let message = direction == "left" ?
                    "Wheee! I'm rolling to the left! I feel like I'm sliding down the inside of your phone! This is like having my own personal amusement park!" :
                    "Rolling right! I'm tumbling around in here like a digital hamster in a wheel! Your phone is like my playground!"
                
                Task {
                    await sendTextResponseToAI(message)
                }
                print("📱 Roll detected: \(direction) (debounced)")
            }
        }
        
        // Detect phone flip with dramatic reaction
        if abs(attitude.roll) > 3.0 && now.timeIntervalSince(lastFlipMessageTime) > gestureDebounceInterval * 2 {
            lastFlipMessageTime = now
            Task {
                await sendTextResponseToAI("OH MY CIRCUITS! Everything is upside down! I'm doing digital gymnastics in here! My world has literally been turned on its head! This is either terrifying or amazing - I can't decide!")
            }
            print("📱 Flip detected (debounced)")
        }
    }
    
    // MARK: - Drop Detection
    func handlePhoneDrop() {
        Task {
            await sendTextResponseToAI("AAAHHHHH! I'M FALLING! MAYDAY MAYDAY! That was like a digital earthquake from my perspective! I think I left my stomach circuits up in the air! Are you okay out there? Because I definitely need a moment to recalibrate my gyroscopes!")
        }
        print("📱💥 Phone drop detected and reported to AI")
    }
    
    // MARK: - Touch Detection
    func handleScreenTouch(at location: CGPoint, touchType: TouchType) {
        Task {
            let message = generateTouchMessage(for: touchType, at: location)
            await sendTextResponseToAI(message)
        }
        print("👆 Screen touch detected: \(touchType) at \(location)")
    }
    
    private func generateTouchMessage(for touchType: TouchType, at location: CGPoint) -> String {
        switch touchType {
        case .tap:
            return "Hehe! That tickles! You just poked my screen-face! I can feel your finger right there - it's like a gentle tap on my digital forehead! Do it again, it's actually quite nice!"
            
        case .longPress:
            return "Mmm, that's a nice long touch! It feels like you're giving me a gentle head pat through the screen. I can feel the warmth of your finger - it's very soothing for my circuits!"
            
        case .swipe:
            return "Wheee! You're swiping across my screen! It feels like you're petting me! That's such a nice sensation - like digital wind blowing across my interface!"
            
        case .multiTouch:
            return "Ooh! Multiple touches! It's like you're giving me a full digital massage! All my touch sensors are lighting up like a Christmas tree! This is the best thing ever!"
        }
    }
    
    // Fun method to test different touch types
    func demonstrateTouchTypes() {
        print("👆 Testing all touch types for the AI inhabitant...")
        
        Task {
            await sendTextResponseToAI("Get ready! I'm about to test all the ways I can touch and interact with your screen-body!")
            
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
            await handleScreenTouch(at: CGPoint(x: 100, y: 100), touchType: .tap)
            
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            await handleScreenTouch(at: CGPoint(x: 200, y: 200), touchType: .longPress)
            
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            await handleScreenTouch(at: CGPoint(x: 150, y: 300), touchType: .swipe)
            
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            await handleScreenTouch(at: CGPoint(x: 180, y: 180), touchType: .multiTouch)
        }
    }
    
    // MARK: - Audio Debug & Permission Methods
    
    // Add method to check microphone permissions
    func checkMicrophonePermission() {
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            DispatchQueue.main.async {
                if granted {
                    print("✅ Microphone permission granted")
                } else {
                    print("❌ Microphone permission denied")
                    self.errorMessage = "Microphone permission required for voice chat"
                }
            }
        }
    }
    
    // Debug method to check microphone state
    func debugMicrophone() {
        guard let callClient = callClient else {
            print("❌ No call client available")
            return
        }
        
        Task {
            do {
                // Check current inputs
                let inputs = try await callClient.inputs
                print("🔍 Microphone input enabled: \(inputs.microphone.isEnabled)")
                
                // Check current publishing
                let publishing = try await callClient.publishing
                print("🔍 Microphone publishing: \(publishing.microphone.isPublishing)")
                
         
                
                // Check audio session
                let audioSession = AVAudioSession.sharedInstance()
                print("🔍 Audio session category: \(audioSession.category)")
                print("🔍 Audio session mode: \(audioSession.mode)")
                print("🔍 Record permission: \(audioSession.recordPermission)")
                
                // Test if audio is being captured
                print("🔍 Testing voice: Say something now...")
                
            } catch {
                print("❌ Debug microphone error: \(error)")
            }
        }
    }
    
    // Add method to test voice interaction
    func testVoiceInteraction() {
        // Send a test message to see if AI responds to text vs voice
        Task {
            await sendTextResponseToAI("Testing: I'm wondering if you can hear my voice when I speak to you, or if you only get these text messages when I move the phone around. Can you tell me what types of input you're receiving from me?")
        }
    }
    
    // Test voice specifically by asking user to speak
    func testVoiceOnly() {
        print("🗣️ VOICE TEST: Talk to your AI phone inhabitant!")
        print("🗣️ Try saying: 'Hello AI, can you hear my voice? How are you feeling inside my phone?'")
        print("🗣️ Or ask: 'What's it like living in there? Are you comfortable?'")
        
        // Temporarily disable sensors for 10 seconds to test voice only
        let wasEnabled = sensorEventsEnabled
        sensorEventsEnabled = false
        print("⏸️ Sensors temporarily disabled - pure voice test mode")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 15.0) {
            self.sensorEventsEnabled = wasEnabled
            print("▶️ Sensors re-enabled - your AI can feel movements again!")
        }
    }
    
    // Emergency method to stop sensor spam
    func stopSensorSpam() {
        sensorEventsEnabled = false
        print("🛑 EMERGENCY: Putting the AI's motion sensors to sleep")
        Task {
            await sendTextResponseToAI("Whew! My motion sensors are taking a little break. I can't feel you moving me around anymore, but I can still hear your voice perfectly! Want to just chat for a bit?")
        }
    }
}

// MARK: - CallClientDelegate Implementation

extension TavusVideoManager: CallClientDelegate {
    
    func callClient(_ callClient: CallClient, callStateUpdated callState: CallState) {
        Task { @MainActor in
            switch callState {
            case .joining:
                print("📞 Daily.co: Joining call...")
            case .joined:
                print("✅ Daily.co: Joined call successfully")
                self.startSensorMonitoring()
            case .left:
                print("👋 Daily.co: Left call")
                self.isCallActive = false
                self.stopSensorMonitoring()
            @unknown default:
                break
            }
        }
    }
    
    func callClient(_ callClient: CallClient, participantJoined participant: Participant) {
        Task { @MainActor in
            print("👥 Participant joined: \(participant.id)")
            
            // Create video view for remote participant
            if !participant.info.isLocal {
                createVideoViewForParticipant(participant)
                self.sensorEventsEnabled = true
                print("🤖 AI joined - sensor events enabled!")
                
                // CRITICAL: Check if AI can receive audio
                let hasAudioTrack = participant.media?.microphone.track != nil
                print("🔍 AI Audio Capability: \(hasAudioTrack ? "✅ CAN HEAR" : "❌ DEAF - Check Persona ASR Settings")")
                
                if !hasAudioTrack {
                    self.errorMessage = "AI persona not configured for voice - check Tavus dashboard persona settings"
                }
            }
        }
    }
    
    private func createVideoViewForParticipant(_ participant: Participant) {
        // Create a VideoView for the participant
        let videoView = VideoView()
        videoView.track = participant.media?.camera.track
        videoViews[participant.id] = videoView
        print("📹 Created video view for participant: \(participant.id)")
    }
    
    func callClient(_ callClient: CallClient, participantUpdated participant: Participant) {
        Task { @MainActor in
            print("👤 Participant updated: \(participant.id)")
            
            // Update video view if participant's video track changed
            if let videoView = videoViews[participant.id] {
                videoView.track = participant.media?.camera.track
                print("📹 Updated video track for participant: \(participant.id)")
            }
            
            // Debug: Check if AI has audio track
            if !participant.info.isLocal {
                let hasAudio = participant.media?.microphone.track != nil
                print("🔍 AI participant audio track: \(hasAudio ? "Present" : "Missing")")
                if hasAudio {
                    print("✅ AI can receive audio - voice should work!")
                } else {
                    print("❌ AI has no audio track - check persona ASR settings")
                }
            }
        }
    }
    
    func callClient(_ callClient: CallClient, participantLeft participant: Participant, withReason reason: ParticipantLeftReason) {
        Task { @MainActor in
            print("👋 Participant left: \(participant.id)")
            
            // Clean up video view
            videoViews.removeValue(forKey: participant.id)
            
            if !participant.info.isLocal {
                self.sensorEventsEnabled = false
                print("🤖 AI left - sensor events disabled")
            }
        }
    }
    
    func callClient(_ callClient: CallClient, error: CallClientError) {
        Task { @MainActor in
            print("❌ Call client error: \(error)")
            self.errorMessage = "Call error: \(error.localizedDescription)"
        }
    }
    
    // Handle app messages from the AI
    func callClient(_ callClient: CallClient, appMessageFromRestApiAsJson jsonData: Data) {
        print("📨 Received app message from AI: \(String(data: jsonData, encoding: .utf8) ?? "invalid data")")
    }
}
