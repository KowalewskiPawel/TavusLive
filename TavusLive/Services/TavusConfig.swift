//
//  TavusConfig.swift
//  TavusLive
//
//  Created by Pawel Kowalewski on 13/06/2025.
//


import Foundation



struct TavusConfig {
    static let tavusAPIKey = ""
    static let tavusBaseURL = "https://tavusapi.com"
    
    // LiveKit connection details will be provided by Tavus
    struct LiveKitConnection {
        let url: String
        let token: String
        let roomName: String
    }
}

//// MARK: - Simple Error Handling
//enum TavusError: Error {
//    case apiError(String)
//    case invalidResponse
//    case networkError(Error)
//    
//    var localizedDescription: String {
//        switch self {
//        case .apiError(let message):
//            return "API Error: \(message)"
//        case .invalidResponse:
//            return "Invalid response from server"
//        case .networkError(let error):
//            return "Network error: \(error.localizedDescription)"
//        }
//    }
//}

// MARK: - Simple Data Models
struct TavusPersona: Codable {
    let personaId: String
    let name: String
    let systemPrompt: String
    
    enum CodingKeys: String, CodingKey {
        case personaId = "persona_id"
        case name
        case systemPrompt = "system_prompt"
    }
}

struct TavusConversation: Codable {
    let conversationId: String
    let conversationName: String
    let conversationUrl: String
    let status: String
    
    enum CodingKeys: String, CodingKey {
        case conversationId = "conversation_id"
        case conversationName = "conversation_name"
        case conversationUrl = "conversation_url"
        case status
    }
}

// MARK: - Minimal API Client
class TavusAPIClient {
    
    private let session: URLSession
    
    init() {
        self.session = URLSession.shared
    }
    
    // MARK: - Helper Methods
    private func makeRequest(url: URL, method: String = "GET", body: Data? = nil) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(TavusConfig.tavusAPIKey, forHTTPHeaderField: "x-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        return request
    }
    
    // MARK: - Essential Methods Only
    func testAPIConnection() async throws {
        guard let url = URL(string: "\(TavusConfig.tavusBaseURL)/v2/replicas") else {
            throw TavusError.apiError("Invalid URL")
        }
        
        let request = makeRequest(url: url, method: "GET")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TavusError.invalidResponse
        }
        
        print("API Test Response Status: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 401 {
            throw TavusError.apiError("Invalid API key")
        } else if httpResponse.statusCode >= 400 {
            throw TavusError.apiError("HTTP \(httpResponse.statusCode)")
        }
        
        print("API Connection successful!")
    }
    
    func createSimpleConversation(personaId: String, replicaId: String? = nil) async throws -> TavusConversation {
        guard let url = URL(string: "\(TavusConfig.tavusBaseURL)/v2/conversations") else {
            throw TavusError.apiError("Invalid URL")
        }
        
        var requestData: [String: Any] = [
            "persona_id": personaId,
            "conversation_name": "iOS Test Chat"
        ]
        
        if let replicaId = replicaId {
            requestData["replica_id"] = replicaId
        }
        
        let requestBody = try JSONSerialization.data(withJSONObject: requestData)
        let request = makeRequest(url: url, method: "POST", body: requestBody)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TavusError.invalidResponse
        }
        
        print("Create conversation status: \(httpResponse.statusCode)")
        print("Response: \(String(data: data, encoding: .utf8) ?? "nil")")
        
        if httpResponse.statusCode >= 400 {
            if let errorDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = errorDict["message"] as? String {
                throw TavusError.apiError(message)
            } else {
                throw TavusError.apiError("HTTP \(httpResponse.statusCode)")
            }
        }
        
        let conversation = try JSONDecoder().decode(TavusConversation.self, from: data)
        return conversation
    }
    
    func createTestPersona() async throws -> TavusPersona {
        guard let url = URL(string: "\(TavusConfig.tavusBaseURL)/v2/personas") else {
            throw TavusError.apiError("Invalid URL")
        }
        
        let requestData: [String: Any] = [
            "name": "iOS Test Assistant",
            "system_prompt": "You are a helpful AI assistant for testing iOS apps."
        ]
        
        let requestBody = try JSONSerialization.data(withJSONObject: requestData)
        let request = makeRequest(url: url, method: "POST", body: requestBody)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TavusError.invalidResponse
        }
        
        if httpResponse.statusCode >= 400 {
            throw TavusError.apiError("HTTP \(httpResponse.statusCode)")
        }
        
        let persona = try JSONDecoder().decode(TavusPersona.self, from: data)
        return persona
    }
    
    func getConversations() async throws -> [TavusConversation] {
        guard let url = URL(string: "\(TavusConfig.tavusBaseURL)/v2/conversations") else {
            throw TavusError.apiError("Invalid URL")
        }
        
        let request = makeRequest(url: url, method: "GET")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TavusError.invalidResponse
        }
        
        if httpResponse.statusCode >= 400 {
            return []  // Return empty array if fails
        }
        
        // Try to decode as array
        if let conversations = try? JSONDecoder().decode([TavusConversation].self, from: data) {
            return conversations
        }
        
        return []
    }
    
    func removeConversation(id: String) async throws {
        guard let url = URL(string: "\(TavusConfig.tavusBaseURL)/v2/conversations/\(id)") else {
            throw TavusError.apiError("Invalid URL")
        }
        
        let request = makeRequest(url: url, method: "DELETE")
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TavusError.invalidResponse
        }
        
        print("Delete conversation status: \(httpResponse.statusCode)")
    }
    
    func removeAllConversations() async throws -> Int {
        let conversations = try await getConversations()
        var deletedCount = 0
        
        for conversation in conversations {
            do {
                try await removeConversation(id: conversation.conversationId)
                deletedCount += 1
            } catch {
                print("Failed to delete: \(error)")
            }
        }
        
        return deletedCount
    }
}
