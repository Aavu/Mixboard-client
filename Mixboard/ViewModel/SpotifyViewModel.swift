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
    
    init() {
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
        
        let urlString = "https://api.spotify.com/v1/search?q=\(truncatedText)&type=album,artist,track&limit=50"
        let url = URL(string: urlString)!
        
        let header = NetworkManager.Header(value: "\(cred.token_type) \(cred.access_token)", key: "Authorization")
        
        var subscription: AnyCancellable?
        subscription = NetworkManager.request(url: url, type: .GET, headers: [header])
            .decode(type: Spotify.SearchResult.self, decoder: JSONDecoder())
            .sink(receiveCompletion: NetworkManager.handleCompletion, receiveValue: { [weak self] (result) in
                self?.songs = result.tracks.items
                subscription?.cancel()
            })
    }
    
    func getRecommendations(numTracks: Int) {
        getCredentials { credentials in
            guard let cred = credentials else {
                print("credentials is nil")
                return
            }
            
            let url = URL(string: "https://api.spotify.com/v1/recommendations?limit=\(numTracks)&seed_genres=pop")!
            
            let header = NetworkManager.Header(value: "\(cred.token_type) \(cred.access_token)", key: "Authorization")
            
            var subscription: AnyCancellable?
            subscription = NetworkManager.request(url: url, type: .GET, headers: [header])
                .decode(type: Spotify.Library.self, decoder: JSONDecoder())
                .sink(receiveCompletion: NetworkManager.handleCompletion, receiveValue: { [weak self] (lib) in
                    print("Got recommendations")
                    self?.songs = lib.tracks
                    subscription?.cancel()
                })
        }
    }
    
    func getCredentials(callback: @escaping (_ credentials: Spotify.Credentials?) -> ()) {
        let url = URL(string: "https://accounts.spotify.com/api/token")!
        
        let client_id = "9cc782e618e04cfbbb447abe7d1d4902"; // Your client id
        let client_secret = "52b3cc1ab3934ec6beaf28a837a134c4"; // Your secret
        
        let authToken = "\(client_id):\(client_secret)".toBase64()
        let bodyParams = "grant_type=client_credentials"
        
        let authHeader = NetworkManager.Header(value: "Basic \(authToken)", key: "Authorization")
        
        var subscription: AnyCancellable?
        subscription = NetworkManager.request(url: url, type: .POST, httpbody: bodyParams.data(using: String.Encoding.ascii, allowLossyConversion: true), contentType: .FORM, headers: [authHeader])
            .decode(type: Spotify.Credentials.self, decoder: JSONDecoder())
            .sink(receiveCompletion: NetworkManager.handleCompletion, receiveValue: { [weak self] (credentials) in
                self?.credentials = credentials
                callback(credentials)
                subscription?.cancel()
            })
    }
    
    func getSpotifySong(songId: String, completion: @escaping (_ spotifyTrack: Spotify.Track?) -> ()) {
        for song in songs {
            if song.id == songId {
                completion(song)
                return
            }
        }
        
        // If the chosen song is not part of the recommendation.
        // This happens when the user cancels search after selecting a song from the searched song list
        getCredentials { credentials in
            guard let cred = credentials else {
                print("credentials is nil")
                return
            }
            
            let url = URL(string: "https://api.spotify.com/v1/tracks/\(songId)")!
            
            let header = NetworkManager.Header(value: "\(cred.token_type) \(cred.access_token)", key: "Authorization")
            
            var subscription: AnyCancellable?
            subscription = NetworkManager.request(url: url, type: .GET, headers: [header])
                .decode(type: Spotify.Track.self, decoder: JSONDecoder())
                .sink(receiveCompletion: NetworkManager.handleCompletion, receiveValue: { (track) in
                    completion(track)
                    subscription?.cancel()
                })
        }
    }
    
    func getSong(songId: String) -> Song? {
        for song in songs {
            if song.id == songId {
                return Song(album: song.album.name, artist: song.artists[0].name, id: songId, img_url: song.album.images[0].url, name: song.name, release_date: song.album.release_date)
            }
        }
        return nil
    }
}
