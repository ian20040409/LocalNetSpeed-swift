//
//  WebView.swift
//  LocalNetSpeed
//
//  Created by 林恩佑 on 2025/8/15.
//


import SwiftUI
import WebKit

struct WebView: UIViewRepresentable {
    let url: URL
    let allowsBackForwardNavigationGestures: Bool
    
    init(url: URL, allowsBackForwardNavigationGestures: Bool = true) {
        self.url = url
        self.allowsBackForwardNavigationGestures = allowsBackForwardNavigationGestures
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        // 需要的話可在這裡調整 preferences 或 userContentController
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.allowsBackForwardNavigationGestures = allowsBackForwardNavigationGestures
        webView.customUserAgent = "LocalNetSpeedApp"
        let request = URLRequest(url: url)
        webView.load(request)
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        // 若之後需要重新載入或動態變更可在此處理
    }
}

#if os(macOS)
struct WebViewMac: NSViewRepresentable {
    let url: URL
    let allowsBackForwardNavigationGestures: Bool
    
    init(url: URL, allowsBackForwardNavigationGestures: Bool = true) {
        self.url = url
        self.allowsBackForwardNavigationGestures = allowsBackForwardNavigationGestures
    }
    
    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.allowsBackForwardNavigationGestures = allowsBackForwardNavigationGestures
        let request = URLRequest(url: url)
        webView.load(request)
        return webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) { }
}
#endif

struct FastComView: View {
    @State private var reloadToken = 0
    
    var body: some View {
        #if os(macOS)
        ZStack {
            WebViewMac(url: URL(string: "https://fast.com")!)
                .id(reloadToken)
            overlayControls
        }
        #else
        ZStack {
            WebView(url: URL(string: "https://fast.com")!)
                .id(reloadToken)
            overlayControls
        }
        #endif
    }
    
    private var overlayControls: some View {
        VStack {
            HStack {
                Spacer()
                Button {
                    reloadToken += 1  // 透過變更 id 重新建立 WebView 達到重新整理
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .padding()
            }
            Spacer()
        }
    }
}