//
//  SpotifyViewModel.swift
//  Mashup
//
//  Created by Raghavasimhan Sankaranarayanan on 10/13/22.
//

import Foundation
import Combine

class SpotifyViewModel: ObservableObject {
    
    @Published var songs = [Spotify.Track]()
    @Published var searchText = ""
    
    private var credentials:Spotify.Credentials?
    
    private var cancellables = Set<AnyCancellable>()
    
    init(numTracks: Int) {
        self.getRecommendations(numTracks: numTracks)
        addSubscribers()
    }
    
    func addSubscribers() {
        $searchText
            .debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
            .sink { [weak self] txt in
                if self?.credentials == nil {
                    self?.getCredentials(callback: { credentials in
                        self?.searchSpotify(txt: txt, credentials: credentials)
                    })
                } else {
                    self?.searchSpotify(txt: txt, credentials: self?.credentials)
                }
            }.store(in: &cancellables)
    }
    
    func searchSpotify(txt: String, credentials: Spotify.Credentials?) {
        if txt.isEmpty { return }
        
        let truncatedText = txt.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).replacingOccurrences(of: " ", with: "+")
        
        
        guard let cred = credentials else {
            print("credentials is nil")
            return
        }
        
        let urlString = "https://api.spotify.com/v1/search?q=\(truncatedText)&type=track"
        guard let url = URL(string: urlString) else {
            print("Error: Url invalid... \(urlString)")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("\(cred.token_type) \(cred.access_token)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, err in
            guard let data = data, err == nil else {
                return
            }
            
            do {
                let result = try JSONDecoder().decode(Spotify.SearchResult.self, from: data)
                DispatchQueue.main.async {
                    self.songs = result.tracks.items
                }
            } catch let e{
                print("error getting Spotify search results")
                print(e)
            }
            
        }.resume()
    }
    
    func getRecommendations(numTracks: Int) {
        getCredentials { credentials in
            guard let cred = credentials else {
                print("credentials is nil")
                return
            }
            
            guard let url = URL(string: "https://api.spotify.com/v1/recommendations?limit=\(numTracks)&seed_genres=pop") else {
                print("Error: Url invalid")
                return
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.addValue("\(cred.token_type) \(cred.access_token)", forHTTPHeaderField: "Authorization")
            
            URLSession.shared.dataTask(with: request) { data, response, err in
                guard let data = data, err == nil else {
                    return
                }
                
                do {
//                    let resp = try JSONSerialization.jsonObject(with: data)
//                    print(resp)
                    let lib = try JSONDecoder().decode(Spotify.Library.self, from: data)
                    DispatchQueue.main.async {
                        print("Got recommendations")
                        self.songs = lib.tracks
                    }
                } catch let e{
                    print("error getting Spotify recommendations")
                    print(e)
                }
                
            }.resume()
        }
    }
    
    func getCredentials(callback: @escaping (_ credentials: Spotify.Credentials?) -> ()) {
        guard let url = URL(string: "https://accounts.spotify.com/api/token") else {
            print("Error: Url invalid")
            return
        }
        
        let client_id = "9cc782e618e04cfbbb447abe7d1d4902"; // Your client id
        let client_secret = "52b3cc1ab3934ec6beaf28a837a134c4"; // Your secret
        
        let authToken = "\(client_id):\(client_secret)".toBase64()
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Basic \(authToken)", forHTTPHeaderField: "Authorization")
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let bodyParams = "grant_type=client_credentials"
        request.httpBody = bodyParams.data(using: String.Encoding.ascii, allowLossyConversion: true)
        
        URLSession.shared.dataTask(with: request) { data, response, err in
            guard let data = data, err == nil else {
                return
            }
            
            do {
                let credentials = try JSONDecoder().decode(Spotify.Credentials.self, from: data)
                self.credentials = credentials
                callback(credentials)
            } catch {
                print("error getting Spotify access token")
            }
        }.resume()
    }
    
    func getSong(songId: String) -> Spotify.Track? {
        for song in songs {
            if song.id == songId {
                return song
            }
        }
        
        return nil
    }
}
