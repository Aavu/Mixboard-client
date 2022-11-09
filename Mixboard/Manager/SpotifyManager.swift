//
//  SpotifyManager.swift
//  Mixboard
//
//  Created by Raghavasimhan Sankaranarayanan on 11/6/22.
//

import Foundation
import Combine
import SwiftUI

class SpotifyManager: ObservableObject {
    static var shared = SpotifyManager()
    
    let redirectUrl = "mixboard-app://spotify-login-callback"
    private let clientSecret = "d7874f7b3f6b44de89c671b778e05be4"
    
    @AppStorage("spotifyCode") var code: String?
    @AppStorage("spotifyUserToken") var userToken: String?
    @AppStorage("spotifyClientToken") var clientToken: String?
    
    @Published var isLinked = false
    
    enum TokenType: String {
        case Bearer
        case Basic
    }
    
//    func createJWT(email: String) -> String? {
//        struct FireBaseClaims: Claims {
//            var alg = "HS256"
//            let iss: String
//            let sub: String
//            var aud = "https://identitytoolkit.googleapis.com/google.identity.identitytoolkit.v1.IdentityToolkit"
//            let exp: Date
//            let iat: Date
//
//            let uid: String
//        }
//        let fbClaims = FireBaseClaims(iss: email, sub: email, exp: Date(timeIntervalSinceNow: 3600), iat: Date(), uid: UUID().uuidString)
//
////        let privateKeyString = "-----BEGIN RSA PRIVATE KEY-----\n" + clientSecret + "\n-----END RSA PRIVATE KEY-----"
//        guard let privateKey = clientSecret.data(using: .utf8) else { return nil }
//        let jwtSigner = JWTSigner.hs256(key: privateKey)
//        let jwtEncoder = JWTEncoder(jwtSigner: jwtSigner)
//        do {
//            let jwtString = try jwtEncoder.encodeToString(JWT(claims: fbClaims))
//            return jwtString
//        } catch (let e) {
//            print(e)
//        }
//
//        return nil
//    }
    
    
    func setCode(code: String) {
        self.code = code
        self.isLinked = true
    }
    
    func getAuthUrl() -> URL {
        let clientId = "b1d26731d5c54bdc8aa1805178acea32"
        
        let baseUrl = "https://accounts.spotify.com/authorize"
        let scopes = ["user-top-read", "user-read-email"].joined(separator: "%20")
        
        let responseType = "code"
        
        let urlString = "\(baseUrl)?client_id=\(clientId)&redirect_uri=\(redirectUrl)&scope=\(scopes)&response_type=\(responseType)"
        
        return URL(string: urlString)!
    }
    
    func getAuthHeader(tokenType: TokenType, accessToken: String? = nil) -> NetworkManager.Header {
        var value = ""
        switch tokenType {
        case .Basic:
            let client_id = "b1d26731d5c54bdc8aa1805178acea32" //"9cc782e618e04cfbbb447abe7d1d4902"; // Your client id
            let client_secret = "d7874f7b3f6b44de89c671b778e05be4" //"52b3cc1ab3934ec6beaf28a837a134c4"; // Your secret
            
            let authToken = "\(client_id):\(client_secret)".toBase64()
            value = "Basic \(authToken)"
        case .Bearer:
            value = "Bearer \(accessToken ?? "")"
        }
        
        return NetworkManager.Header(value: value, key: "Authorization")
    }
    
    func getCredentials(grantType: Spotify.GrantType = .client, callback: @escaping (_ credentials: Spotify.Credentials?) -> ()) {
        
        switch grantType {
        case .code:
            if let token = userToken {
                callback(Spotify.Credentials(access_token: token, expires_in: 3600, token_type: "Bearer"))
                return
            }
        case .client:
            if let token = clientToken {
                callback(Spotify.Credentials(access_token: token, expires_in: 3600, token_type: "Bearer"))
                return
            }
        }
        
//        if let refreshToken = self.credentials?.refresh_token {
//            getRefreshToken { credentials in
//                self.credentials!.refresh_token = credentials?.access_token
//                print("refreshed token:", refreshToken)
//                callback(self.credentials)
//            }
//        } else {
//
//        }
        
        let url = URL(string: "https://accounts.spotify.com/api/token")!
        
        var body: [String:String]!
        switch grantType {
        case .client:
            body = ["grant_type": "client_credentials"]
        case .code:
            body = ["grant_type": "authorization_code", "code": code!, "redirect_uri": redirectUrl]
        }
        let authHeader = self.getAuthHeader(tokenType: .Basic)
        var subscription: AnyCancellable?
        subscription = NetworkManager.request(url: url, type: .POST, httpbody: NetworkManager.getAsHttpBody(body: body), contentType: .FORM, headers: [authHeader])
            .decode(type: Spotify.Credentials.self, decoder: JSONDecoder())
            .sink(receiveCompletion: NetworkManager.handleCompletion, receiveValue: { (credentials) in
                switch grantType {
                case .code:
                    self.userToken = credentials.access_token
                case .client:
                    self.clientToken = credentials.access_token
                }
                callback(credentials)
                subscription?.cancel()
            })
    }
    
//    func getRefreshToken( callback: @escaping (_ credentials: Spotify.Credentials?) -> ()) {
//        let url = URL(string: "https://accounts.spotify.com/api/token")!
//        let authHeader = self.getAuthHeader(tokenType: .Basic)
//        let body = ["grant_type": "refresh_token", "refresh_token": self.credentials[.code]?.refresh_token ?? ""]
//        print(body)
//
//        var subscription: AnyCancellable?
//        subscription = NetworkManager.request(url: url, type: .POST, httpbody: self.getAsHttpBody(body: body), contentType: .FORM, headers: [authHeader])
//            .decode(type: Spotify.Credentials.self, decoder: JSONDecoder())
//            .sink(receiveCompletion: NetworkManager.handleCompletion, receiveValue: { (credentials) in
//                callback(credentials)
//                subscription?.cancel()
//            })
//    }
    
    func getUserInfo(completion: @escaping (_ userInfo: Spotify.UserInfo) -> ()) {
        getCredentials(grantType: .code) { credentials in
            guard let cred = credentials else {
                print("Function: \(#function), line: \(#line),", "credentials is nil")
                return
            }
            let url = URL(string: "https://api.spotify.com/v1/me")!
            
            let authHeader = self.getAuthHeader(tokenType: .Bearer, accessToken: cred.access_token)
            
            var subscription: AnyCancellable?
            subscription = NetworkManager.request(url: url, type: .GET, contentType: .JSON, headers: [authHeader])
                .decode(type: Spotify.UserInfo.self, decoder: JSONDecoder())
                .sink(receiveCompletion: NetworkManager.handleCompletion, receiveValue: { info in
                    subscription?.cancel()
                    completion(info)
                })
        }
        
        
    }
    
    func getSong(songId: String, completion: @escaping (_ spotifyTrack: Spotify.Track?) -> ()) {
        getCredentials { credentials in
            guard let cred = credentials else {
                print("Function: \(#function), line: \(#line),", "credentials is nil")
                return
            }
            
            let url = URL(string: "https://api.spotify.com/v1/tracks/\(songId)")!
            
            let header = self.getAuthHeader(tokenType: .Bearer, accessToken: cred.access_token)
            
            var subscription: AnyCancellable?
            subscription = NetworkManager.request(url: url, type: .GET, headers: [header])
                .decode(type: Spotify.Track.self, decoder: JSONDecoder())
                .sink(receiveCompletion: NetworkManager.handleCompletion, receiveValue: { (track) in
                    completion(track)
                    subscription?.cancel()
                })
        }
    }
    
    func getRecommendations(numTracks: Int, forUser: Bool, completion: @escaping (_ spotifyTracks: [Spotify.Track]?) -> ()) {
        getCredentials(grantType: forUser ? .code : .client) { credentials in
            guard let cred = credentials else {
                print("Function: \(#function), line: \(#line),", "credentials is nil")
                return
            }
            
            var url: URL!
            let header = self.getAuthHeader(tokenType: .Bearer, accessToken: cred.access_token)
            var subscription: AnyCancellable?
            
            if forUser {
                url = URL(string: "https://api.spotify.com/v1/me/top/tracks?limit=\(numTracks)")!
                subscription = NetworkManager.request(url: url, type: .GET, headers: [header])
                    .decode(type: Spotify.SearchResult.STrack.self, decoder: JSONDecoder())
                    .sink(receiveCompletion: NetworkManager.handleCompletion, receiveValue: { (result) in
                        subscription?.cancel()
                        completion(result.items)
                    })
            } else {
                url = URL(string: "https://api.spotify.com/v1/recommendations?limit=\(numTracks)&seed_genres=pop")!
                
                subscription = NetworkManager.request(url: url, type: .GET, headers: [header])
                    .decode(type: Spotify.Library.self, decoder: JSONDecoder())
                    .sink(receiveCompletion: NetworkManager.handleCompletion, receiveValue: { (lib) in
                        subscription?.cancel()
                        completion(lib.tracks)
                    })
            }
        }
    }
    
    func searchSpotify(txt: String, completion: @escaping (_ spotifyTracks: [Spotify.Track]?) -> ()) {
        if txt.isEmpty { return }
        
        let truncatedText = txt.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).replacingOccurrences(of: " ", with: "+")
        
        self.getCredentials { credentials in
            guard let cred = credentials else {
                print("Function: \(#function), line: \(#line),", "credentials is nil")
                return
            }
            
            let urlString = "https://api.spotify.com/v1/search?q=\(truncatedText)&type=album,artist,track&limit=50"
            let url = URL(string: urlString)!
            
            let header = self.getAuthHeader(tokenType: .Bearer, accessToken: cred.access_token)
            
            var subscription: AnyCancellable?
            subscription = NetworkManager.request(url: url, type: .GET, headers: [header])
                .decode(type: Spotify.SearchResult.self, decoder: JSONDecoder())
                .sink(receiveCompletion: NetworkManager.handleCompletion, receiveValue: { (result) in
                    completion(result.tracks.items)
                    subscription?.cancel()
                })
        }
        
    }
}
