//
//  TavusManager.swift
//  TavusLive
//
//  Created by Pawel Kowalewski on 13/06/2025.
//

import Foundation
import SwiftUI

@MainActor
class TavusManager: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var conversationURL: String?
    @Published var currentConversation: TavusConversation?
    @Published var apiTestStatus: String?
    @Published var activeConversations: [TavusConversation] = []
    @Published var cleanupStatus: String?
    
    private let apiClient = TavusAPIClient()
    
    func testAPIConnection() async {
        isLoading = true
        errorMessage = nil
        apiTestStatus = "Testing API connection..."
        
        do {
            try await apiClient.testAPIConnection()
            apiTestStatus = "✅ API connection successful!"
        } catch {
            apiTestStatus = "❌ API connection failed"
            errorMessage = "API Test Failed: \(error.localizedDescription)"
            print("API Test Error: \(error)")
        }
        
        isLoading = false
    }
    
    func startConversation(personaId: String, replicaId: String? = nil) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let conversation = try await apiClient.createSimpleConversation(
                personaId: personaId,
                replicaId: replicaId
            )
            
            currentConversation = conversation
            conversationURL = conversation.conversationUrl
            
            print("Created conversation: \(conversation.conversationId)")
            print("Conversation URL: \(conversation.conversationUrl)")
            
        } catch let error as TavusError {
            if case .apiError(let message) = error,
               message.contains("maximum concurrent conversations") {
                errorMessage = "Too many active conversations. Please clean up existing conversations first."
                await loadActiveConversations()
            } else {
                errorMessage = "Failed to create conversation: \(error.localizedDescription)"
            }
            print("Error creating conversation: \(error)")
        } catch {
            errorMessage = "Failed to create conversation: \(error.localizedDescription)"
            print("Error creating conversation: \(error)")
        }
        
        isLoading = false
    }
    
    func createTestPersona() async -> String? {
        do {
            let persona = try await apiClient.createTestPersona()
            print("Created test persona: \(persona.personaId)")
            return persona.personaId
        } catch {
            errorMessage = "Failed to create test persona: \(error.localizedDescription)"
            return nil
        }
    }
    
    func loadActiveConversations() async {
        do {
            activeConversations = try await apiClient.getConversations()
            print("Found \(activeConversations.count) active conversations")
        } catch {
            print("Failed to load conversations: \(error)")
            errorMessage = "Failed to load conversations: \(error.localizedDescription)"
        }
    }
    
    func cleanupAllConversations() async {
        isLoading = true
        cleanupStatus = "Cleaning up conversations..."
        errorMessage = nil
        
        do {
            let deletedCount = try await apiClient.removeAllConversations()
            cleanupStatus = "✅ Deleted \(deletedCount) conversations"
            activeConversations.removeAll()
            
            // Wait a moment for cleanup to complete
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            await loadActiveConversations()
            
        } catch {
            cleanupStatus = "❌ Cleanup failed"
            errorMessage = "Cleanup failed: \(error.localizedDescription)"
            print("Cleanup error: \(error)")
        }
        
        isLoading = false
    }
    
    func endConversation() {
        conversationURL = nil
        currentConversation = nil
        errorMessage = nil
    }
    
    func clearError() {
        errorMessage = nil
        cleanupStatus = nil
        apiTestStatus = nil
    }
}
