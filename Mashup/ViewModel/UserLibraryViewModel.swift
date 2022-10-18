//
//  UserLibraryViewModel.swift
//  Mashup
//
//  Created by Raghavasimhan Sankaranarayanan on 10/14/22.
//

import Foundation

class UserLibraryViewModel: ObservableObject {
    @Published var songs = [Song]()
    @Published var downloadProgress = Dictionary<String, Int>()
    @Published var isSelected = Dictionary<String, Bool>()
    
    private var lib: LibraryViewModel?
    
    func attachLibrary(library: LibraryViewModel) {
        self.lib = library
    }
    
    func isSongSelected(songId: String) -> Bool {
        return isSelected[songId] ?? false
    }
    
    func addSongs(songs: Dictionary<String, SongSource>) {
        for (id, _) in songs {
            addSong(songId: id)
        }
    }
    
    func addSong(songId: String) {
        guard let lib = self.lib else { return }
        
        guard let url = URL(string: Config.SERVER + HttpRequests.ADD_SONG) else {
            print("Error: Url invalid")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Application/json", forHTTPHeaderField: "Content-Type")
        
        let data = ["url" : songId]
        request.httpBody = try? JSONSerialization.data(withJSONObject: data)
        
        URLSession.shared.dataTask(with: request) { data, response, err in
            guard let _ = data, err == nil else {
                return
            }
            
            lib.update(didUpdate: {
                let song = lib.getSong(songId: songId)
                self.replaceDummy(song: song)
                print("library updated")
            })
            
        }.resume()
        
        let song = lib.getSong(songId: songId)
        self.songs.append(song)
        self.isSelected[songId] = false
    }
    
    func replaceDummy(song: Song) {
        for i in (0..<songs.count) {
            if songs[i].id == song.id {
                songs[i] = song
                return
            }
        }
    }
    
    func removeSong(songId: String) {
        guard let lib = self.lib else { return }
        
        guard let url = URL(string: Config.SERVER + HttpRequests.REMOVE_SONG) else {
            print("Error: Url invalid")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Application/json", forHTTPHeaderField: "Content-Type")
        
        let data = ["url" : songId]
        request.httpBody = try? JSONSerialization.data(withJSONObject: data)
        
        URLSession.shared.dataTask(with: request) { data, response, err in
            guard let _ = data, err == nil else {
                return
            }
            
            lib.update(didUpdate: {
                self.songs.removeAll { song in
                    song.id == songId
                }
            })
            
        }.resume()
    }
}
