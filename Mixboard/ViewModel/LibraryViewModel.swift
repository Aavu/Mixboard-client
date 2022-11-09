//
//  LibraryViewModel.swift
//  Mashup
//
//  Created by Raghavasimhan Sankaranarayanan on 10/14/22.
//

import Foundation
import Combine

class LibraryViewModel: ObservableObject {
    @Published var library: Library?
    private var unfilteredSongs = [Song]()
    private var userLibSongs = [Song]()
    @Published var songs = [Song]()
    
    @Published var searchText = ""
    
    private var cancellables = Set<AnyCancellable>()
    init() {
        addSubscribers()
    }
    
    func addSubscribers() {
        $searchText
            .debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
            .map { (txt) -> [Song] in
                guard !txt.isEmpty else {
                    return self.unfilteredSongs
                }
                
                let lowerTxt = txt.lowercased().trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                
                return self.unfilteredSongs.filter { song in
                    return song.name?.lowercased().contains(lowerTxt) ?? false ||
                    song.album?.lowercased().contains(lowerTxt) ?? false ||
                    song.artist?.lowercased().contains(lowerTxt) ?? false
                }
            }
            .sink { filteredSongs in
                self.songs = filteredSongs
            }
            .store(in: &cancellables)
    }
    
    func isSongInList(list: [Song], song: Song) -> Bool {
        if list.isEmpty {
            return false
        }
        
        for s in list {
            if s.id == song.id {
                return true
            }
        }
        return false
    }
    
    func loadExampleData() -> Bool {
        guard let url = Bundle.main.url(forResource: "libraryExample", withExtension: "json")
        else {
            print("Function: \(#function), line: \(#line),", "Json file not found")
            return false
        }
        
        do {
            let data = try Data(contentsOf: url)
            self.library = try JSONDecoder().decode(Library.self, from: data)
        } catch let e {
            print("Function: \(#function), line: \(#line),", e)
            return false
        }
        return true
    }
    
    func filterUserLibSongs(songs: [Song]) {
        self.userLibSongs = songs
        if self.userLibSongs.isEmpty {
            return
        }
        self.songs = {
            return self.unfilteredSongs.filter { song in
                return !isSongInList(list: self.userLibSongs, song: song)
            }
        }()
    }
    
    func update(didUpdate: ((Error?) -> ())? = nil) {
        let url = URL(string: Config.SERVER + HttpRequests.TRACK_LIST)!
        
        var subscription: AnyCancellable?
        subscription = NetworkManager.request(url: url, type: .POST)
            .decode(type: Library.self, decoder: JSONDecoder())
            .sink(receiveCompletion: { completion in
                switch completion {
                case .finished:
                    break
                case .failure(let e):
                    if let didUpdate = didUpdate {
                        didUpdate(e)
                    }
                }
            }, receiveValue: { [weak self] (lib) in
                self?.library = lib
                self?.updateSongList()
                if let didUpdate = didUpdate {
                    didUpdate(nil)
                }
                subscription?.cancel()
            })
    }
    
    private func updateSongList() {
        guard let library = self.library else { return }
        self.songs = []
        self.unfilteredSongs = []
        for (_, v) in library.items {
            self.songs.append(v)
            self.unfilteredSongs.append(v)
        }
    }
    
    func getSong(songId: String) -> Song? {
        guard let library = self.library else { return Song(id: songId) }
        return library.items[songId]
    }
    
    func addSong(song: Song) -> Bool {
        guard let library = self.library else { return false }
        if (library.items[song.id] == nil) {
            self.library!.items[song.id] = song
            updateSongList()
        }
        
        return true
    }
    
    //TODO: Content repeats with SpotifyVM getSong function. DRY!!!
    func addSong(spotifySong: Spotify.Track) -> Bool {
        var song = Song(id: spotifySong.id)
        song.album = spotifySong.album.name
        song.artist = spotifySong.artists[0].name
        song.external_url = spotifySong.external_urls.spotify
        song.img_url = spotifySong.album.images[0].url
        song.name = spotifySong.name
        song.preview_url = spotifySong.preview_url
        song.release_date = spotifySong.album.release_date
        
        return addSong(song: song)
    }
}
