import SwiftUI
import WebKit
import UniformTypeIdentifiers

/// Wraps the bundled booking site (www source: the repo's index.html) in a WKWebView
/// so it behaves like a native app: external links (mailto, tel, Instagram, Add to
/// Calendar) open in the system rather than dead-ending inside the web view, and the
/// admin dashboard's CSV export triggers a real file download + share sheet.
struct WebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = false
        webView.scrollView.bounces = false
        webView.isOpaque = false
        webView.backgroundColor = UIColor(red: 8 / 255, green: 12 / 255, blue: 30 / 255, alpha: 1)
        webView.scrollView.backgroundColor = webView.backgroundColor

        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKDownloadDelegate {
        private var pendingDownloadFilename: String?

        // Links the page opens with target="_blank" or window.open() (Instagram,
        // "Add to Calendar") land here instead of silently doing nothing.
        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if let url = navigationAction.request.url {
                UIApplication.shared.open(url)
            }
            return nil
        }

        // Regular in-page navigations: keep the bundled site inside the app, but
        // hand mailto:/tel: and any other external scheme to the system.
        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }

            if navigationAction.shouldPerformDownload {
                decisionHandler(.download)
                return
            }

            let scheme = url.scheme?.lowercased() ?? ""
            if scheme == "mailto" || scheme == "tel" || scheme == "sms" {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                return
            }

            if url.isFileURL {
                decisionHandler(.allow)
                return
            }

            // http(s) navigation that isn't the bundled page itself (e.g. a booking
            // confirmation deep link) opens in Safari rather than replacing the app UI.
            if (scheme == "http" || scheme == "https") && navigationAction.targetFrame == nil {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                return
            }

            decisionHandler(.allow)
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationResponse: WKNavigationResponse,
            decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
        ) {
            if navigationResponse.canShowMIMEType {
                decisionHandler(.allow)
            } else {
                decisionHandler(.download)
            }
        }

        func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
            download.delegate = self
        }

        func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
            download.delegate = self
        }

        // Admin dashboard's "Export CSV" button: save to a temp file, then hand the
        // user a share sheet so they can save it to Files, AirDrop it, etc.
        func download(
            _ download: WKDownload,
            decideDestinationUsing response: URLResponse,
            suggestedFilename: String,
            completionHandler: @escaping (URL?) -> Void
        ) {
            pendingDownloadFilename = suggestedFilename
            let dest = FileManager.default.temporaryDirectory.appendingPathComponent(suggestedFilename)
            try? FileManager.default.removeItem(at: dest)
            completionHandler(dest)
        }

        func downloadDidFinish(_ download: WKDownload) {
            guard let filename = pendingDownloadFilename else { return }
            let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            DispatchQueue.main.async {
                Self.presentShareSheet(for: fileURL)
            }
        }

        private static func presentShareSheet(for url: URL) {
            guard
                let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController
            else { return }

            var top = root
            while let presented = top.presentedViewController { top = presented }

            let activity = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            if let popover = activity.popoverPresentationController {
                popover.sourceView = top.view
                popover.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            top.present(activity, animated: true)
        }
    }
}

struct ContentView: View {
    var body: some View {
        if let url = Bundle.main.url(forResource: "index", withExtension: "html") {
            WebView(url: url)
                .ignoresSafeArea()
        } else {
            VStack(spacing: 12) {
                Text("Couldn't load the booking site.")
                    .font(.headline)
                Text("index.html is missing from the app bundle.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }
}
