//
//  ContentView.swift
//  TavusLive
//
//  Created by Pawel Kowalewski on 13/06/2025.
//
 
import SwiftUI
import Daily

struct ContentView: View {
    @StateObject private var manager = TavusVideoManager()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                Text("🤖 AI Sensor Companion")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                // Status indicators
                VStack(spacing: 10) {
                    HStack {
                        Circle()
                            .fill(manager.conversationURL != nil ? .green : .gray)
                            .frame(width: 12, height: 12)
                        Text("Conversation: \(manager.conversationURL != nil ? "Ready" : "Not Created")")
                    }
                    
                    HStack {
                        Circle()
                            .fill(manager.isCallActive ? .green : .gray)
                            .frame(width: 12, height: 12)
                        Text("Video Call: \(manager.isCallActive ? "Active" : "Inactive")")
                    }
                    
                    HStack {
                        Circle()
                            .fill(manager.sensorEventsEnabled ? .green : .gray)
                            .frame(width: 12, height: 12)
                        Text("Sensors: \(manager.sensorEventsEnabled ? "Monitoring" : "Disabled")")
                    }
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
                
                Spacer()
                
                // Main action buttons
                VStack(spacing: 15) {
                    // Create conversation button
                    Button(action: {
                        Task {
                            await manager.createConversation()
                        }
                    }) {
                        HStack {
                            Image(systemName: "plus.bubble")
                            Text("Create AI Conversation")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(manager.isLoading || manager.conversationURL != nil)
                    
                    // Join video call button
                    Button(action: {
                        Task {
                            await manager.joinVideoCall()
                        }
                    }) {
                        HStack {
                            Image(systemName: "video")
                            Text("Join Video Call")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(manager.conversationURL != nil ? Color.green : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(manager.isLoading || manager.conversationURL == nil || manager.isCallActive)
                }
                
                // Sensor testing section
                if manager.sensorEventsEnabled {
                    VStack(spacing: 10) {
                        Text("🎮 Sensor Controls")
                            .font(.headline)
                        
                        Text("Try these gestures:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .leading, spacing: 5) {
                            Text("📳 Shake phone - Get AI attention")
                            Text("📳📳 Double shake - Interrupt AI")
                            Text("📱 Tilt phone - Show movement")
                            Text("🔄 Flip upside down - AI reacts")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                        
                        // Manual drop test button
                        Button("🫳 Simulate Phone Drop") {
                            manager.handlePhoneDrop()
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                
                Spacer()
                
                // Error message
                if let errorMessage = manager.errorMessage {
                    Text("❌ \(errorMessage)")
                        .foregroundColor(.red)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                }
                
                // Loading indicator
                if manager.isLoading {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Processing...")
                    }
                    .foregroundColor(.secondary)
                }
            }
            .padding()
            .navigationTitle("AI Companion")
            .navigationBarTitleDisplayMode(.inline)
        }
        // Native Daily.co video call sheet (replaces Safari)
        .sheet(isPresented: $manager.isCallActive) {
            DailyVideoCallView(manager: manager)
        }
    }
}


#Preview {
    ContentView()
}
