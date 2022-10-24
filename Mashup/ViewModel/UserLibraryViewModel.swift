//
//  UserLibraryViewModel.swift
//  Mashup
//
//  Created by Raghavasimhan Sankaranarayanan on 10/14/22.
//

import Foundation
import Combine

class UserLibraryViewModel: ObservableObject {
    @Published var songs = [Song]()
    @Published var downloadProgress = Dictionary<String, Int>()
    @Published var isSelected = Dictionary<String, Bool>()
    
    static let TOTAL_PROGRESS = 100
    
    private var lib: LibraryViewModel?
    private var spotifyVM: SpotifyViewModel?
    
    private var errorSubscriber: AnyCancellable?
    @Published var appError: AppError?
    @Published var showError = false
    
    init() {
        addSubscriber()
    }
    
    func addSubscriber() {
        errorSubscriber = $appError.sink {[weak self] err in
            self?.showError = (err != nil)
        }
    }
    
    func attachViewModels(library: LibraryViewModel, spotifyViewModel: SpotifyViewModel) {
        self.lib = library
        self.spotifyVM = spotifyViewModel
    }
    
    func isSongSelected(songId: String) -> Bool {
        return isSelected[songId] ?? false
    }
    
    func isSongInLibrary(songId: String) -> Bool {
        return lib?.getSong(songId: songId) != nil
    }
    
    func addSongs(songs: Dictionary<String, SongSource>) {
        for (id, _) in songs {
            addSong(songId: id)
        }
    }
    
    func addSong(songId: String) {
        guard let lib = self.lib else { return }
        
        for song in self.songs {
            if song.id == songId {
                print("Song already in library")
                return
            }
        }
        
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
            guard let data = data, err == nil else {
                return
            }
            
            
            DispatchQueue.main.async {
                if let song = self.spotifyVM?.getSpotifySong(songId: songId) {
                    if let success = self.lib?.addSong(spotifySong: song) {
                        if success {
                            self.addSongFromLib(songId: songId)
                        } else {
                            print("Error adding \(song.name) to library")
                        }
                    }
                }
            }
            
            do {
                let resp = try JSONSerialization.jsonObject(with: data) as! Dictionary<String, String>
                guard let taskId = resp["task_id"] else { return }
                self.updateStatus(taskId: taskId, songId: songId)
            } catch let err {
                print(err)
            }
            
            lib.update(didUpdate: {
                if let song = lib.getSong(songId: songId) {
                    self.replaceDummy(song: song)
                    print("library updated")
                }
            })
            
        }.resume()
        
        addSongFromLib(songId: songId)
    }
    
    func addSongFromLib(songId: String) {
        if let song = lib?.getSong(songId: songId) {
            if !isSongInLib(songId: songId) {
                print("Adding \(String(describing: song.name)) to library")
                self.songs.append(song)
                self.isSelected[songId] = false
            }
        }
    }
    
    func isSongInLib(songId: String) -> Bool {
        for s in self.songs {
            if s.id == songId {
                return true
            }
        }
        
        return false
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
    
    func restoreFromHistory(history: History) {
        songs = [Song]()
        for song in history.userLibrary {
            addSongFromLib(songId: song.id)
        }
    }
    
    func updateStatus(taskId: String, songId: String, tryNum: Int = 0) {
        if self.downloadProgress[songId] == 100 { return }
        
        guard let url = URL(string: Config.SERVER + HttpRequests.STATUS + "/" + taskId) else {
            print("Error: Url invalid")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Application/json", forHTTPHeaderField: "Content-Type")
        
        DispatchQueue.main.async {
            if self.downloadProgress[songId] == nil {
                self.downloadProgress[songId] = 10
            }
        }
        
        URLSession.shared.dataTask(with: request) { data, response, err in
            guard let data = data, err == nil else {
                return
            }
            
            do {
                let resp = try JSONSerialization.jsonObject(with: data) as! Dictionary<String, Any>
                print(resp)
                if let stat = RequestStatus(rawValue: resp["requestStatus"] as! String) {
                    switch stat {
                    case .Progress:
                        let result = try JSONDecoder().decode(TaskStatus.self, from: data)
                        DispatchQueue.main.async {
                            self.downloadProgress[songId] = result.task_result.progress
                            print("\(songId) download progress: \(String(describing: self.downloadProgress[songId]))")
                            self.updateStatus(taskId: taskId, songId: songId)  //  Recursive call
                        }
                        
                    case .Success:
                        DispatchQueue.main.async {
                            self.downloadProgress[songId] = 100
                            print("\(songId) downloaded!")
                        }
                        
                        if let lib = self.lib {
                            lib.update(didUpdate: {
                                if let song = lib.getSong(songId: songId) {
                                    self.replaceDummy(song: song)
                                    print("library updated")
                                }
                            })
                        }
                        
                    default:
                        print("Request Status: \(stat.rawValue)")
                    }
                }
                
            } catch let err {
                print("Error decoding task status: ", err)
                print("trying again...")
                if tryNum < 3 {
                    self.updateStatus(taskId: taskId, songId: songId, tryNum: tryNum + 1)  //  Recursive call
                }
            }
            
        }.resume()
    }
}
