//
//  TavusWebView.swift
//  TavusLive
//
//  Created by Pawel Kowalewski on 13/06/2025.
//


import SwiftUI
import WebKit

struct TavusWebView: UIViewRepresentable {
    let conversationURL: String
    @Binding var isLoading: Bool
    @Binding var error: String?
    
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        
        // Allow camera and microphone access
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        
        // Enable debugging if needed
        #if DEBUG
        webView.isInspectable = true
        #endif
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        guard let url = URL(string: conversationURL) else {
            error = "Invalid conversation URL"
            return
        }
        
        // Create request with proper headers
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        
        webView.load(request)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        let parent: TavusWebView
        
        init(_ parent: TavusWebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = true
                self.parent.error = nil
            }
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                self.parent.error = "Failed to load: \(error.localizedDescription)"
            }
        }
        
        // Handle permission requests (camera/microphone)
        func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType, decisionHandler: @escaping (WKPermissionDecision) -> Void) {
            // Grant permission for camera and microphone
            decisionHandler(.grant)
        }
        
        // Handle JavaScript alerts, confirms, etc.
        func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
            DispatchQueue.main.async {
                print("WebView Alert: \(message)")
                completionHandler()
            }
        }
        
        func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
            DispatchQueue.main.async {
                print("WebView Confirm: \(message)")
                completionHandler(true) // Auto-confirm for now
            }
        }
    }
}
