import SwiftUI
import WebKit
import AppKit

struct WebView: NSViewRepresentable {
    let htmlContent: String
    @Binding var dynamicHeight: CGFloat
    
    class NonScrollingWebView: WKWebView {
        override func scrollWheel(with event: NSEvent) {
            nextResponder?.scrollWheel(with: event)
        }
    }

    func makeNSView(context: Context) -> WKWebView {
        let webView = NonScrollingWebView()
        webView.setValue(false, forKey: "drawsBackground")
        webView.navigationDelegate = context.coordinator
        return webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        let css = """
        <style>
        :root {
            color-scheme: light dark;
        }
        body {
            font-family: -apple-system, system-ui, sans-serif;
            font-size: 13px;
            line-height: 1.5;
            color: -apple-system-label;
            margin: 0;
            padding: 0;
            overflow-wrap: break-word;
            overflow: hidden;
        }
        a { color: -apple-system-blue; text-decoration: none; }
        a:hover { text-decoration: underline; }
        img { max-width: 100%; height: auto; }
        pre {
            background-color: -apple-system-tertiary-system-fill;
            padding: 12px;
            border-radius: 6px;
            overflow-x: auto;
            font-family: ui-monospace, SFMono-Regular, SF Mono, Menlo, Consolas, Liberation Mono, monospace;
        }
        code {
            font-family: ui-monospace, SFMono-Regular, SF Mono, Menlo, Consolas, Liberation Mono, monospace;
            font-size: 12px;
            background-color: -apple-system-quaternary-system-fill;
            padding: 0.2em 0.4em;
            border-radius: 6px;
        }
        pre code {
            background-color: transparent;
            padding: 0;
        }
        blockquote {
            border-left: 0.25em solid -apple-system-separator;
            color: -apple-system-secondary-label;
            padding: 0 1em;
            margin-left: 0;
        }
        ul, ol { padding-left: 2em; }
        table {
            border-spacing: 0;
            border-collapse: collapse;
            width: 100%;
        }
        td, th {
            padding: 6px 13px;
            border: 1px solid -apple-system-separator;
        }
        tr:nth-child(2n) {
            background-color: -apple-system-quaternary-system-fill;
        }
        </style>
        """
        
        let html = css + htmlContent
        nsView.loadHTMLString(html, baseURL: nil)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebView
        
        init(_ parent: WebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.evaluateJavaScript("document.body.scrollHeight") { (result, error) in
                if let height = result as? CGFloat {
                    DispatchQueue.main.async {
                        self.parent.dynamicHeight = height
                    }
                }
            }
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.navigationType == .linkActivated {
                if let url = navigationAction.request.url {
                    NSWorkspace.shared.open(url)
                }
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }
    }
}