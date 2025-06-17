//
//  LiveKitTavusView.swift
//  TavusLive
//
//  Created by Pawel Kowalewski on 16/06/2025.
//

import SwiftUI
import Daily

// MARK: - Fixed TavusVideoView with Real Video
struct TavusVideoView: View {
    @ObservedObject var manager: TavusVideoManager
    
    var body: some View {
        ZStack {
            // Real Daily.co video view
            DailyVideoCallView(manager: manager)
            
            // Overlay controls
            VStack {
                Spacer()
                controlsView
            }
        }
    }
    
    private var controlsView: some View {
        VStack(spacing: 15) {
            // Call status
            HStack {
                Text("📞 Call Status:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                Text(manager.isCallActive ? "CONNECTED" : "DISCONNECTED")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(manager.isCallActive ? .green : .red)
                
                Spacer()
            }
            
            // Sensor controls
            if manager.sensorEventsEnabled {
                HStack(spacing: 10) {
                    Button("📳 Test Shake") {
                        print("Manual shake test triggered")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.2))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    
                    Button("🫳 Test Drop") {
                        manager.handlePhoneDrop()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.2))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    
                    Button("🎤 \(manager.isMicEnabled ? "Mute" : "Unmute")") {
                        manager.toggleMicrophone()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(manager.isMicEnabled ? Color.green.opacity(0.3) : Color.red.opacity(0.3))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    
                    Button("🔍 Debug Mic") {
                        manager.debugMicrophone()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.3))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    
                    Button("🗣️ Test Voice") {
                        manager.testVoiceInteraction()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.purple.opacity(0.3))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    
               
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.3))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    
               
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.red.opacity(0.3))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    
                    Button("🎭 Touch Demo") {
                        manager.demonstrateTouchTypes()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.purple.opacity(0.3))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    
                    Button("📺 Check Captions") {
                        print("💡 Look for captions in video call - if you see captions when you speak, ASR is working!")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.3))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color.black.opacity(0.3))
    }
}

// MARK: - Real Daily.co Video View with Touch Detection
struct DailyVideoCallView: UIViewRepresentable {
    @ObservedObject var manager: TavusVideoManager
    
    func makeUIView(context: Context) -> TouchDetectingView {
        let containerView = TouchDetectingView()
        containerView.backgroundColor = UIColor.black
        containerView.manager = manager
        
        // Add participant video views when available
        if let videoView = manager.getVideoView() {
            containerView.addSubview(videoView)
            videoView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                videoView.topAnchor.constraint(equalTo: containerView.topAnchor),
                videoView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                videoView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                videoView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
            ])
        }
        
        return containerView
    }
    
    func updateUIView(_ uiView: TouchDetectingView, context: Context) {
        // Update video views when participants change
        uiView.manager = manager
    }
}

// Custom UIView that detects touches and reports them to the AI
class TouchDetectingView: UIView {
    weak var manager: TavusVideoManager?
    private var touchStartTime: Date?
    private let longPressThreshold: TimeInterval = 0.5
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        touchStartTime = Date()
        
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        if touches.count > 1 {
            manager?.handleScreenTouch(at: location, touchType: .multiTouch)
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        
        guard let touch = touches.first,
              let startTime = touchStartTime else { return }
        
        let location = touch.location(in: self)
        let touchDuration = Date().timeIntervalSince(startTime)
        
        if touchDuration >= longPressThreshold {
            manager?.handleScreenTouch(at: location, touchType: .longPress)
        } else {
            manager?.handleScreenTouch(at: location, touchType: .tap)
        }
        
        touchStartTime = nil
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        // Detect swipe (touch moved significantly)
        manager?.handleScreenTouch(at: location, touchType: .swipe)
    }
}

// MARK: - Fixed ConnectionView
struct ConnectionView: View {
    @ObservedObject var manager: TavusVideoManager
    
    var body: some View {
        VStack(spacing: 30) {
            if manager.isLoading {
                // Loading state
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(2)
                    
                    Text("Creating AI Video Call...")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("Setting up conversation with Tavus AI")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            } else {
                // Ready to connect state
                VStack(spacing: 20) {
                    Image(systemName: "video.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("🤖 Ready to Connect")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Start your AI companion video call")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [.black, .gray.opacity(0.8)]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

// MARK: - Complete TavusLiveView (Fixed)
struct TavusLiveView: View {
    @StateObject private var manager = TavusVideoManager()
    
    var body: some View {
        ZStack {
            if manager.isCallActive {
                // Active video call
                TavusVideoView(manager: manager)
            } else {
                // Connection/setup screen
                ConnectionView(manager: manager)
            }
            
            // Error overlay
            if let errorMessage = manager.errorMessage {
                VStack {
                    Spacer()
                    
                    Text("❌ \(errorMessage)")
                        .foregroundColor(.red)
                        .padding()
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(10)
                        .padding()
                }
            }
        }
        .onAppear {
            // Start the connection process
            Task {
                await manager.createConversation()
                if manager.conversationURL != nil {
                    await manager.joinVideoCall()
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    TavusLiveView()
}
