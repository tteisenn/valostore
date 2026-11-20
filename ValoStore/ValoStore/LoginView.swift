import SwiftUI
import WebKit

/// Riot'un kendi giriş sayfasını açar. Şifre/2FA'yı Riot sayfası alır, uygulama görmez.
/// Giriş bitince yönlendirme adresindeki access_token yakalanır.
struct LoginView: UIViewRepresentable {
    let onToken: (String, Int) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onToken: onToken) }

    func makeUIView(context: Context) -> WKWebView {
        let web = WKWebView(frame: .zero)
        web.navigationDelegate = context.coordinator
        web.load(URLRequest(url: RiotAPI.authorizeURL))
        return web
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        let onToken: (String, Int) -> Void
        init(onToken: @escaping (String, Int) -> Void) { self.onToken = onToken }

        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = navigationAction.request.url,
               url.host == "playvalorant.com",
               let fragment = url.fragment {
                var params: [String: String] = [:]
                for pair in fragment.split(separator: "&") {
                    let kv = pair.split(separator: "=", maxSplits: 1).map(String.init)
                    if kv.count == 2 { params[kv[0]] = kv[1].removingPercentEncoding ?? kv[1] }
                }
                if let token = params["access_token"] {
                    decisionHandler(.cancel)
                    let expires = Int(params["expires_in"] ?? "3600") ?? 3600
                    onToken(token, expires)
                    return
                }
            }
            decisionHandler(.allow)
        }
    }
}
