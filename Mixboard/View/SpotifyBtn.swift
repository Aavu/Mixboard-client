//
//  SpotifyBtn.swift
//  Mixboard
//
//  Created by Raghavasimhan Sankaranarayanan on 11/7/22.
//

import SwiftUI
import WebKit
import FirebaseAuth

struct SpotifyBtn: View {
    @State var showWebView = false
    var spotifyAuthUrl: URL
    
    @State var loadCount: Int = 0
    
    var authCompletion: (Error?) -> ()
    init(authCompletion: @escaping (Error?) -> ()) {
        self.authCompletion = authCompletion
        self.spotifyAuthUrl = SpotifyManager.shared.getAuthUrl()
    }
    
    var body: some View {
        Button {
            showWebView.toggle()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .foregroundColor(.accentColor)
                    .shadow(radius: 2, x: 2, y: 2)
                
                HStack {
                    Text("Link").foregroundColor(.green)
                    Image("SpotifyLogo").resizable().renderingMode(.original).scaledToFit().frame(height: 24)
                }
            }
        }.sheet(isPresented: $showWebView) {
            WebView(url: spotifyAuthUrl) { urlString in
                if let urlString = urlString {
                    let splitUrl = urlString.split(separator: "?")
                    let code = splitUrl[1].split(separator: "=")
                    if code[0] == "code" {
                        SpotifyManager.shared.setCode(code: String(code[1]))
                        showWebView = false
                        authCompletion(nil)
                    } else {
                        print("Function: \(#function), line: \(#line),", "Error getting access token")
                    }
                }
            }
        }
        
    }
}

/// Represents the UIVIEW that wraps WKWebView.
/// Adapted from: `https://medium.com/geekculture/how-to-use-webview-in-swiftui-and-also-detect-the-url-21d4fab2a9c1`
struct WebView: UIViewRepresentable {
    
    var url: URL
    
    var didFinishAuthenticating: (String?) -> ()
        
    func makeUIView(context: Context) -> WKWebView {
        let wkWebView = WKWebView()
        wkWebView.navigationDelegate = context.coordinator
        let request = URLRequest(url: url)
        wkWebView.load(request)
        return wkWebView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
    }
    
    func makeCoordinator() -> WebViewCoordinator {
        WebViewCoordinator(self)
    }
    
    class WebViewCoordinator: NSObject, WKNavigationDelegate {
        var parent: WebView
        
        init(_ parent: WebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            
            if let url = navigationAction.request.url?.absoluteString {
                if url.starts(with: SpotifyManager.shared.redirectUrl) {
                    parent.didFinishAuthenticating(url)
                }
            }
            decisionHandler(.allow)
        }
        
    }
}

struct SpotifyBtn_Previews: PreviewProvider {
    static var previews: some View {
        SpotifyBtn() {err in
        }
    }
}
