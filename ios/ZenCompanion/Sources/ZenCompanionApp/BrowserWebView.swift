#if canImport(SwiftUI) && canImport(WebKit)
import SwiftUI
import WebKit

struct BrowserWebView: UIViewRepresentable {
    enum Command: Equatable {
        case back
        case forward
        case reload
    }

    @Binding var url: URL?
    @Binding var command: Command?
    var onNavigationStateChange: (Bool, Bool) -> Void
    var onPageMetadataChange: (URL, String) -> Void

    final class Coordinator: NSObject, WKNavigationDelegate {
        var parent: BrowserWebView

        init(parent: BrowserWebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.onNavigationStateChange(webView.canGoBack, webView.canGoForward)
            if let url = webView.url {
                let title = webView.title?.trimmingCharacters(in: .whitespacesAndNewlines)
                parent.onPageMetadataChange(url, title?.isEmpty == false ? title! : url.host ?? "Page")
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.onNavigationStateChange(webView.canGoBack, webView.canGoForward)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true

        if let url {
            webView.load(URLRequest(url: url))
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        guard let url else { return }
        if uiView.url != url {
            uiView.load(URLRequest(url: url))
        }
        if let command {
            switch command {
            case .back:
                uiView.goBack()
            case .forward:
                uiView.goForward()
            case .reload:
                uiView.reload()
            }
            DispatchQueue.main.async {
                self.command = nil
            }
        }
        onNavigationStateChange(uiView.canGoBack, uiView.canGoForward)
    }
}
#endif
