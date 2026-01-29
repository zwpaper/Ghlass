import SwiftUI
import WebKit
import AppKit

struct WebView: NSViewRepresentable {
    let htmlContent: String
    @Binding var dynamicHeight: CGFloat
    var isLoading: Binding<Bool>? = nil

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
            padding: 0 0 12px 0;
            overflow-wrap: break-word;
            overflow: hidden;
        }
        a { color: -apple-system-blue; text-decoration: none; }
        a:hover { text-decoration: underline; }
        img {
            max-width: 100%;
            height: auto;
            display: block;
            margin: 0 auto;
        }
        @media (min-width: 600px) {
            img { max-width: 50%; }
        }
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
        body > :last-child {
            margin-bottom: 0 !important;
        }
        </style>
        """

        let html = """
        <!DOCTYPE html>
        <html>
        <head>
        \(css)
        </head>
        <body>
        \(htmlContent.trimmingCharacters(in: .whitespacesAndNewlines))
        </body>
        </html>
        """

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
            // Recursive function to remove trailing whitespace/br tags/empty elements
            let script = """
                (function() {
                    function isVisuallyEmpty(node) {
                        if (node.nodeType === 3) { // Text node
                            return !node.textContent.trim();
                        }
                        if (node.nodeType === 1) { // Element
                            if (node.tagName === 'BR') return true;
                            if (node.tagName === 'IMG' || node.tagName === 'HR' || node.tagName === 'IFRAME' || node.tagName === 'VIDEO') return false;

                            // Check children
                            var hasContent = false;
                            for (var i = 0; i < node.childNodes.length; i++) {
                                if (!isVisuallyEmpty(node.childNodes[i])) {
                                    hasContent = true;
                                    break;
                                }
                            }
                            return !hasContent;
                        }
                        return true;
                    }

                    function removeTrailingEmptyElements(element) {
                        if (!element) return;
                        var lastNode = element.lastChild;

                        while (lastNode) {
                            if (isVisuallyEmpty(lastNode)) {
                                var toRemove = lastNode;
                                lastNode = lastNode.previousSibling;
                                toRemove.remove();
                            } else {
                                // If it's an element, try to clean its end
                                if (lastNode.nodeType === 1) {
                                    removeTrailingEmptyElements(lastNode);
                                    // After cleaning inside, check if it became empty
                                    if (isVisuallyEmpty(lastNode)) {
                                        var toRemove = lastNode;
                                        lastNode = lastNode.previousSibling;
                                        toRemove.remove();
                                        continue;
                                    }
                                }
                                break;
                            }
                        }
                    }

                    removeTrailingEmptyElements(document.body);

                    // Return the height
                    return document.body.scrollHeight;
                })();
            """

            webView.evaluateJavaScript(script) { (result, error) in
                if let height = result as? CGFloat {
                    DispatchQueue.main.async {
                        // Only update if the height is different to avoid loops, though SwiftUI handles this well
                        if self.parent.dynamicHeight != height {
                            self.parent.dynamicHeight = height
                        }
                        self.parent.isLoading?.wrappedValue = false
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