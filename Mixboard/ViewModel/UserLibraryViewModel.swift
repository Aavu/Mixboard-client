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
    @Published var downloadProgress = Dictionary<String, TaskStatus.Status>()
    private var downloadFailure = false
    @Published var isSelected = Dictionary<String, Bool>()
    @Published var silenceOverlayText = Dictionary<String, String>()
    @Published var dragOffset = Dictionary<String, CGSize>()
    
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
    
    func addSongs(songIds: [String]) {
        for id in songIds {
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
        
        let url = URL(string: Config.SERVER + HttpRequests.ADD_SONG)!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Application/json", forHTTPHeaderField: "Content-Type")
        
        let data = ["url" : songId]
        request.httpBody = try? JSONSerialization.data(withJSONObject: data)
        
        URLSession.shared.dataTask(with: request) { data, response, err in
            guard let data = data, err == nil else {
                DispatchQueue.main.async {
                    self.appError = AppError(description: err?.localizedDescription)
                }
                return
            }
            
            
            DispatchQueue.main.async {
                if let song = self.spotifyVM?.getSpotifySong(songId: songId) {
                    if let success = self.lib?.addSong(spotifySong: song) {
                        if success {
                            self.addSongFromLib(songId: songId)
                        } else {
                            self.appError = AppError(description: "Error adding \(song.name) to library")
                        }
                    }
                }
            }
            
            do {
                let resp = try JSONSerialization.jsonObject(with: data) as! Dictionary<String, String>
                guard let taskId = resp["task_id"] else { return }
                self.updateStatus(taskId: taskId, songId: songId)
            } catch let err {
                DispatchQueue.main.async {
                    self.appError = AppError(description: err.localizedDescription)
                }
            }
            
            lib.update(didUpdate: {
                if let song = lib.getSong(songId: songId) {
                    self.replaceDummy(song: song)
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
    
    func hasNonSilentBoundsFor(song: Song, lane: Lane) -> Bool {
        let beats = [4, 8, 16, 32]
        
        switch lane {
        case .Vocals:
            for beat in beats {
                if !(song.non_silent_bounds?.vocals["\(beat)"]?.isEmpty ?? false) {
                    return true
                }
            }
        case .Other:
            for beat in beats {
                if !(song.non_silent_bounds?.other["\(beat)"]?.isEmpty ?? false) {
                    return true
                }
            }
        case .Bass:
            for beat in beats {
                if !(song.non_silent_bounds?.bass["\(beat)"]?.isEmpty ?? false) {
                    return true
                }
            }
        case .Drums:
            for beat in beats {
                if !(song.non_silent_bounds?.drums["\(beat)"]?.isEmpty ?? false) {
                    return true
                }
            }
        }
        
        return false
    }
    
    func removeSong(songId: String, notifyServer: Bool = true, completion: ((Error?) -> ())? = nil) {
        guard let lib = self.lib else { return }
        
        if notifyServer {
            let url = URL(string: Config.SERVER + HttpRequests.REMOVE_SONG)!
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Application/json", forHTTPHeaderField: "Content-Type")
            
            let data = ["url" : songId]
            request.httpBody = try? JSONSerialization.data(withJSONObject: data)
            
            URLSession.shared.dataTask(with: request) { data, response, err in
                guard let _ = data, err == nil else {
                    self.appError = AppError(description: err?.localizedDescription)
                    if let completion = completion {
                        completion(err)
                    }
                    return
                }
                
                lib.update(didUpdate: {
                    self.songs.removeAll { song in
                        song.id == songId
                    }
                    
                    if let completion = completion {
                        completion(nil)
                    }
                })
                
            }.resume()
        } else {
            lib.update(didUpdate: {
                self.songs.removeAll { song in
                    song.id == songId
                }
                
                if let completion = completion {
                    completion(nil)
                }
            })
        }
    }
    
    func restoreFromHistory(history: History) {
        songs = [Song]()
        for song in history.userLibrary {
            addSongFromLib(songId: song.id)
        }
    }
    
    func updateStatus(taskId: String, songId: String, tryNum: Int = 0) {
        if self.downloadProgress[songId]?.progress == 100 { return }
        
        let url = URL(string: Config.SERVER + HttpRequests.STATUS + "/" + taskId)!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Application/json", forHTTPHeaderField: "Content-Type")
        
        DispatchQueue.main.async {
            if self.downloadProgress[songId] == nil {
                self.downloadProgress[songId] = TaskStatus.Status(progress: 10, description: "Downloading Song")
            }
        }
        
        URLSession.shared.dataTask(with: request) { data, response, err in
            guard let data = data, err == nil else {
                DispatchQueue.main.async {
                    self.appError = AppError(description: err?.localizedDescription)
                    self.downloadProgress[songId] = nil
                }
                return
            }
            
            do {
                let resp = try JSONSerialization.jsonObject(with: data) as! Dictionary<String, Any>
                if let stat = RequestStatus(rawValue: resp["requestStatus"] as! String) {
                    switch stat {
                    case .Progress:
                        let result = try JSONDecoder().decode(TaskStatus.self, from: data)
                        DispatchQueue.main.async {
                            self.downloadProgress[songId] = result.task_result
                            self.updateStatus(taskId: taskId, songId: songId)  //  Recursive call
                        }
                        
                    case .Success:
                        DispatchQueue.main.async {
                            self.downloadProgress[songId]?.progress = 100
                            if let str = resp["task_result"] as? String, let err = Int(str) {
                                // If song download fails
                                if err != 0 {
                                    self.appError = AppError(description: "This song cannot be downloaded. Please choose a different song or version")
                                    
                                    self.removeSong(songId: songId, notifyServer: false)
                                    return
                                }
                            }
                        }
                        
                        if let lib = self.lib {
                            lib.update(didUpdate: {
                                if let song = lib.getSong(songId: songId) {
                                    self.replaceDummy(song: song)
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
                DispatchQueue.main.async {
                    if tryNum < 3 {
                        self.updateStatus(taskId: taskId, songId: songId, tryNum: tryNum + 1)  //  Recursive call
                    } else {
                        self.appError = AppError(description: err.localizedDescription)
                        self.downloadProgress[songId] = nil
                    }
                }
            }
            
        }.resume()
    }
}
