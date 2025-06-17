//
//  ConversationView.swift
//  TavusLive
//
//  Created by Pawel Kowalewski on 13/06/2025.
//

import SwiftUI
import UIKit

struct ConversationView: View {
    @ObservedObject var manager: TavusManager
    @State private var showWebView = false
    @Environment(\.dismiss) private var dismiss
    
    let personaId: String
    let replicaId: String?
    
    init(personaId: String, replicaId: String?) {
        self.personaId = personaId
        self.replicaId = replicaId
        self.manager = TavusManager()
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if let conversationURL = manager.conversationURL {
                // Show conversation options
                conversationReadyView(url: conversationURL)
            } else {
                // Start screen
                startScreen
            }
        }
        .navigationBarHidden(true)
    }
    
    // MARK: - Conversation Ready View
    private func conversationReadyView(url: String) -> some View {
        VStack(spacing: 40) {
            // Success indicator
            VStack(spacing: 20) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.green)
                
                Text("🎉 Conversation Created!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Your AI conversation is ready to start")
                    .font(.body)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            
            // URL Display
            VStack(spacing: 10) {
                Text("Conversation URL:")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Text(url)
                    .font(.caption2)
                    .foregroundColor(.blue)
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                    .onTapGesture {
                        UIPasteboard.general.string = url
                    }
                
                Text("(Tap to copy)")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            .padding(.horizontal)
            
            // Action buttons
            VStack(spacing: 20) {
                // Primary: Open in Safari (recommended)
                Button("🌐 Open in Safari (Recommended)") {
                    openInSafari(url: url)
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 40)
                .padding(.vertical, 15)
                .background(Color.green)
                .cornerRadius(25)
                
                // Secondary: Try WebView
                Button("📱 Try WebView (May be slower)") {
                    showWebView = true
                }
                .font(.subheadline)
                .foregroundColor(.blue)
                .padding(.horizontal, 30)
                .padding(.vertical, 12)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(20)
                
                // Tertiary: Create new conversation
                Button("🔄 Create New Conversation") {
                    Task {
                        await manager.startConversation(
                            personaId: personaId,
                            replicaId: replicaId
                        )
                    }
                }
                .font(.subheadline)
                .foregroundColor(.orange)
                .padding(.horizontal, 30)
                .padding(.vertical, 12)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(20)
            }
            
            // Back button
            Button("← Back to Home") {
                dismiss()
            }
            .font(.caption)
            .foregroundColor(.gray)
            .padding(.top, 20)
            
            Spacer()
        }
        .padding()
        .sheet(isPresented: $showWebView) {
            // WebView as a sheet/modal instead of fullscreen
            WebViewSheet(url: url, isPresented: $showWebView)
        }
    }
    
    // MARK: - Start Screen
    private var startScreen: some View {
        VStack(spacing: 30) {
            if manager.isLoading {
                loadingView
            } else {
                readyView
            }
            
            // Error messages
            if let errorMessage = manager.errorMessage {
                errorView(message: errorMessage)
            }
        }
        .padding()
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(2)
            Text("Creating conversation...")
                .foregroundColor(.white)
                .font(.headline)
            Text("This usually takes 5-10 seconds")
                .foregroundColor(.gray)
                .font(.caption)
        }
    }
    
    // MARK: - Ready View
    private var readyView: some View {
        VStack(spacing: 20) {
            Image(systemName: "video.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            Text("AI Video Conversation")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("Start a conversation with an AI persona")
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            
            VStack(spacing: 15) {
                Button("Test API Connection") {
                    Task {
                        await manager.testAPIConnection()
                    }
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 40)
                .padding(.vertical, 15)
                .background(Color.gray)
                .cornerRadius(25)
                
                Button("🚀 Start Conversation") {
                    Task {
                        await manager.startConversation(
                            personaId: personaId,
                            replicaId: replicaId
                        )
                    }
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 40)
                .padding(.vertical, 15)
                .background(Color.blue)
                .cornerRadius(25)
                
                Button("Create Test Persona") {
                    Task {
                        if let testPersonaId = await manager.createTestPersona() {
                            await manager.startConversation(
                                personaId: testPersonaId,
                                replicaId: replicaId
                            )
                        }
                    }
                }
                .font(.subheadline)
                .foregroundColor(.blue)
                .padding(.horizontal, 30)
                .padding(.vertical, 12)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(20)
                
                Button("🧹 Clean Up Conversations") {
                    Task {
                        await manager.cleanupAllConversations()
                    }
                }
                .font(.subheadline)
                .foregroundColor(.white)
                .padding(.horizontal, 30)
                .padding(.vertical, 12)
                .background(Color.orange)
                .cornerRadius(20)
            }
            
            // Status Messages
            statusMessages
        }
    }
    
    // MARK: - Status Messages
    private var statusMessages: some View {
        VStack(spacing: 10) {
            if let status = manager.apiTestStatus {
                Text(status)
                    .font(.caption)
                    .foregroundColor(status.contains("✅") ? .green : .orange)
            }
            
            if let status = manager.cleanupStatus {
                Text(status)
                    .font(.caption)
                    .foregroundColor(status.contains("✅") ? .green : .orange)
            }
            
            if manager.activeConversations.count > 0 {
                Text("Active conversations: \(manager.activeConversations.count)")
                    .font(.caption)
                    .foregroundColor(.yellow)
            }
        }
    }
    
    // MARK: - Error View
    private func errorView(message: String) -> some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                Text(message)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
            
            Button("Try Again") {
                manager.clearError()
            }
            .foregroundColor(.blue)
            .font(.caption)
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(10)
    }
    
    // MARK: - Helper Methods
    private func openInSafari(url: String) {
        guard let safariURL = URL(string: url) else { return }
        UIApplication.shared.open(safariURL)
    }
}

// MARK: - Optimized WebView Sheet
struct WebViewSheet: View {
    let url: String
    @Binding var isPresented: Bool
    @State private var isLoading = true
    @State private var error: String?
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    VStack {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Loading Tavus conversation...")
                            .padding(.top)
                        Text("This may take 30+ seconds for video to start")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.top, 5)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    OptimizedTavusWebView(
                        conversationURL: url,
                        isLoading: $isLoading,
                        error: $error
                    )
                }
                
                if let error = error {
                    VStack {
                        Text("Error: \(error)")
                            .foregroundColor(.red)
                            .padding()
                        
                        Button("Open in Safari Instead") {
                            if let safariURL = URL(string: url) {
                                UIApplication.shared.open(safariURL)
                            }
                            isPresented = false
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                }
            }
            .navigationTitle("Tavus Conversation")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Safari") {
                    if let safariURL = URL(string: url) {
                        UIApplication.shared.open(safariURL)
                    }
                    isPresented = false
                },
                trailing: Button("Done") {
                    isPresented = false
                }
            )
        }
    }
}

// MARK: - Performance-Optimized WebView
struct OptimizedTavusWebView: UIViewRepresentable {
    let conversationURL: String
    @Binding var isLoading: Bool
    @Binding var error: String?
    
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        
        // Optimize for video performance
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.allowsPictureInPictureMediaPlayback = true
        
        // Enable hardware acceleration
        configuration.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        configuration.preferences.setValue(true, forKey: "allowUniversalAccessFromFileURLs")
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        
        // Performance settings
        webView.scrollView.isScrollEnabled = false
        webView.isOpaque = false
        webView.backgroundColor = UIColor.black
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        guard let url = URL(string: conversationURL),
              webView.url != url else { return }
        
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        
        print("Loading optimized WebView URL: \(conversationURL)")
        webView.load(request)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        let parent: OptimizedTavusWebView
        
        init(_ parent: OptimizedTavusWebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("WebView finished loading")
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("WebView failed: \(error)")
            DispatchQueue.main.async {
                self.parent.isLoading = false
                self.parent.error = error.localizedDescription
            }
        }
        
        func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType, decisionHandler: @escaping (WKPermissionDecision) -> Void) {
            print("Granting media permission: \(type.rawValue)")
            decisionHandler(.grant)
        }
    }
}

import WebKit
