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
        update()
        addSubscribers()
    }
    
    func addSubscribers() {
        $searchText
            .debounce(for: .seconds(0.25), scheduler: DispatchQueue.main)
            .map { (txt) -> [Song] in
                guard !txt.isEmpty else {
                    return self.unfilteredSongs
                }
                
                let lowerTxt = txt.lowercased().trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                
//                let sortedSongs = self.unfilteredSongs.sorted { a, b in
//                    var isAleB = LibraryViewModel.levenshteinDist(query: lowerTxt, txt: a.name?.lowercased()) < LibraryViewModel.levenshteinDist(query: lowerTxt, txt: b.name?.lowercased())
//
//                    isAleB = isAleB || LibraryViewModel.levenshteinDist(query: lowerTxt, txt: a.album?.lowercased()) < LibraryViewModel.levenshteinDist(query: lowerTxt, txt: b.album?.lowercased())
//
//                    isAleB = isAleB || LibraryViewModel.levenshteinDist(query: lowerTxt, txt: a.artist?.lowercased()) < LibraryViewModel.levenshteinDist(query: lowerTxt, txt: b.artist?.lowercased())
//
//                    print(a.name!, b.name!, LibraryViewModel.levenshteinDist(query: lowerTxt, txt: a.name?.lowercased()), LibraryViewModel.levenshteinDist(query: lowerTxt, txt: b.name?.lowercased()), a.album!, b.album!, LibraryViewModel.levenshteinDist(query: lowerTxt, txt: a.album?.lowercased()), LibraryViewModel.levenshteinDist(query: lowerTxt, txt: b.album?.lowercased()), a.artist!, b.artist!, LibraryViewModel.levenshteinDist(query: lowerTxt, txt: a.artist?.lowercased()), LibraryViewModel.levenshteinDist(query: lowerTxt, txt: b.artist?.lowercased()))
//
//                    return isAleB
//                }
//
//                return sortedSongs
                
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
    
    
    static private func levenshteinDist(query: String, txt: String?) -> Int {
        guard let txt = txt else { return Int.max }
        
        let empty = Array<Int>(repeating:0, count: query.count)
        var last = [Int](0...query.count)
        
        for (i, testLetter) in txt.enumerated() {
            var cur = [i + 1] + empty
            for (j, queryLetter) in query.enumerated() {
                cur[j + 1] = testLetter == queryLetter ? last[j] : min(last[j], last[j + 1], cur[j]) + 1
            }
            last = cur
        }
        return last.last!
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
        
        NetworkManager.request(url: url, type: .POST, handleCompletion: { completion in
            switch completion {
            case .finished:
                break
            case .failure(let e):
                if let didUpdate = didUpdate {
                    didUpdate(e)
                }
            }
        }) { [weak self] (lib) in
            self?.library = lib
            self?.updateSongList()
            if let didUpdate = didUpdate {
                didUpdate(nil)
            }
        }
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
        guard let library = self.library else { return nil }
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
