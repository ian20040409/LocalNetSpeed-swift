import SwiftUI
import WebKit
#if os(iOS)
import SafariServices
#endif

#if os(iOS)
struct SFSafariView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        return SFSafariViewController(url: url, configuration: config)
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) { }
}
#endif

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
    var body: some View {
        #if os(macOS)
        WebViewMac(url: URL(string: "https://fast.com")!)
        #else
        SFSafariView(url: URL(string: "https://fast.com")!)
            .ignoresSafeArea()
        #endif
    }
}