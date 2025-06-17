//
//  TavusLiveKitManager.swift
//  TavusLive
//
//  Created by Pawel Kowalewski on 16/06/2025.
//

import Foundation
import LiveKit

@MainActor
class TavusLiveKitManager: ObservableObject {
    // MARK: - Published Properties
    @Published var connectionState: ConnectionState = .disconnected
    @Published var room: Room?
    @Published var participants: [Participant] = []
    @Published var localVideoTrack: LocalVideoTrack?
    @Published var remoteVideoTrack: RemoteVideoTrack?
    @Published var isConnecting = false
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    private var tavusConversationId: String?
    
    // MARK: - Public API
    
    /// Creates a Tavus conversation and then connects to the associated LiveKit room.
    func createTavusConversation(personaId: String, replicaId: String? = nil) async throws -> String {
        let url = URL(string: "\(TavusConfig.tavusBaseURL)/v2/conversations")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(TavusConfig.tavusAPIKey, forHTTPHeaderField: "x-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Check if replica_id is provided - it's required for Tavus API
        guard let replicaId = replicaId else {
            throw TavusError.apiError("replica_id is required for creating Tavus conversations")
        }
        
        // Correct format based on Tavus API documentation
        let requestBody: [String: Any] = [
            "replica_id": replicaId,
            "persona_id": personaId,
            "conversation_name": "LiveKit iOS Chat",
            "properties": [
//                "transport_type": "livekit",
                "max_call_duration": 600
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode < 400 else {
            // Log the actual response for debugging
            if let responseData = String(data: data, encoding: .utf8) {
                print("Tavus API Error Response: \(responseData)")
            }
            throw TavusError.apiError("Failed to create conversation. Status code: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
        }
        
        guard let responseDict = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let conversationId = responseDict["conversation_id"] as? String,
              let liveKitUrl = responseDict["livekit_url"] as? String,
              let liveKitToken = responseDict["livekit_token"] as? String else {
            throw TavusError.invalidResponse
        }
        
        // Connect to the LiveKit room using the retrieved credentials.
        try await connectToLiveKit(url: liveKitUrl, token: liveKitToken)
        
        self.tavusConversationId = conversationId
        return conversationId
    }
    
    /// Connects to a LiveKit room with the given URL and token.
    func connectToLiveKit(url: String, token: String) async throws {
        isConnecting = true
        errorMessage = nil
        
        do {
            // FIX 1: Use the correct, simplified Room initializer.
            // The previous initializer `Room(delegate:connectOptions:roomOptions:)` is not a public API.
            // The canonical initializer just takes a delegate.
            let room = Room(delegate: self)
            self.room = room
            
            // Connect to the room. This is an async operation.
            try await room.connect(url: url, token: token)
            
            // Once connected, enable local media. These are also async operations.
            try await room.localParticipant.setCamera(enabled: true)
            try await room.localParticipant.setMicrophone(enabled: true)
            
            // Store the local video track for rendering in the UI.
            self.localVideoTrack = room.localParticipant.firstCameraPublication?.track as? LocalVideoTrack
            
            // Perform an initial participant update.
            await updateParticipants()
            
        } catch {
            self.errorMessage = "Failed to connect to LiveKit: \(error.localizedDescription)"
            // Ensure connection status is reset on failure.
            self.isConnecting = false
            self.room = nil
            throw error
        }
        
        isConnecting = false
    }
    
    /// Disconnects from the LiveKit room and resets all state.
    func disconnect() async {
        // This is a synchronous call. It will trigger delegate callbacks for disconnection.
        await room?.disconnect()
        
        // Reset all state properties. Since this method is on the @MainActor,
        // these UI-related updates are safe.
        room = nil
        connectionState = .disconnected
        participants.removeAll()
        localVideoTrack = nil
        remoteVideoTrack = nil
        tavusConversationId = nil
        isConnecting = false
        errorMessage = nil
    }
    
    // MARK: - Private Helper Methods
    
    /// Updates the participants list and identifies the remote Tavus avatar track.
    private func updateParticipants() async {
        guard let room = self.room else { return }
        
        // Update the main participants array.
        // `allParticipants` includes the local participant, so filter if you only want remotes.
        // Here, we take all participants as the source.
        let allP = room.allParticipants.values
        self.participants = Array(allP)
        
        // Find the Tavus avatar participant and its video track.
        // We iterate through all participants to find the one that matches.
        for participant in allP {
            // We only care about remote participants for the avatar track.
            guard let remoteParticipant = participant as? RemoteParticipant else { continue }
            
            // FIX 2: Use string conversion of identity for comparison
            // Convert the identity to string for contains check
            let identityValue: String = String(describing: remoteParticipant.identity)
            if identityValue.contains("tavus") || identityValue.contains("agent") {
                self.remoteVideoTrack = remoteParticipant.firstCameraPublication?.track as? RemoteVideoTrack
                // Once found, we can break the loop.
                break
            }
        }
    }
    
    /// A dedicated async method to safely update the connectionState from a Task.
    private func setConnectionState(_ state: ConnectionState) {
        self.connectionState = state
    }
}

// MARK: - RoomDelegate Conformance
extension TavusLiveKitManager: RoomDelegate {
    
    // FIX 3: Bridge from `nonisolated` delegate context to `@MainActor` context using `Task`.
    // The `nonisolated` keyword means this method is called from a background thread.
    // To update `@MainActor`-isolated properties like `connectionState`, we must create a `Task`.
    nonisolated func room(_ room: Room, didUpdate connectionState: ConnectionState, from oldValue: ConnectionState) {
        Task {
            await self.setConnectionState(connectionState)
        }
    }
    
    // Using `Task` is the modern, correct way to handle this context switch.
    // `DispatchQueue.main.async` is a legacy GCD pattern and causes errors when mixed with async/await this way.
    nonisolated func room(_ room: Room, participantDidConnect participant: RemoteParticipant) {
        Task {
            await self.updateParticipants()
        }
    }

    nonisolated func room(_ room: Room, participantDidDisconnect participant: RemoteParticipant) {
        Task {
            await self.updateParticipants()
        }
    }
    
    // This delegate is called when a remote participant publishes a new track.
    nonisolated func room(_ room: Room, participant: RemoteParticipant, didPublishTrack publication: RemoteTrackPublication) {
        Task {
            await self.updateParticipants()
        }
    }

    // This delegate is called when we successfully subscribe to a remote track.
    // This is often a better place to update UI than `didPublishTrack`.
    nonisolated func room(_ room: Room, participant: RemoteParticipant, didSubscribeTrack publication: RemoteTrackPublication, track: Track) {
        Task {
            await self.updateParticipants()
        }
    }
    
    nonisolated func room(_ room: Room, participant: RemoteParticipant, didUnpublishTrack publication: RemoteTrackPublication) {
        Task {
            await self.updateParticipants()
        }
    }
}

// MARK: - Custom Error Type
enum TavusError: Error, LocalizedError {
    case apiError(String)
    case invalidResponse
    
    var errorDescription: String? {
        switch self {
        case .apiError(let message):
            return message
        case .invalidResponse:
            return "Invalid or malformed response from Tavus API."
        }
    }
}
