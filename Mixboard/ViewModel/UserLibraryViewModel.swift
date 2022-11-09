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
    @Published var downloadingSong = false
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
    
    func addSongs(songIds: [String: SongSource]) {
        
        // First add local songs
        for (id, src) in songIds {
            if src == .Library {
                addSong(songId: id)
            }
        }
        
        // Then add spotify songs
        for (id, src) in songIds {
            if src == .Spotify {
                addSong(songId: id)
            }
        }
    }
    
    func addSong(songId: String) {
        guard let lib = self.lib else { return }
        
        for song in self.songs {
            if song.id == songId {
                print("Function: \(#function), line: \(#line),", "Song already in library")
                return
            }
        }
        
        let url = URL(string: Config.SERVER + HttpRequests.ADD_SONG)!
        downloadingSong = true
        var subscription: AnyCancellable?
        subscription = NetworkManager.request(url: url, type: .POST, httpbody: try? JSONSerialization.data(withJSONObject: ["url" : songId]))
            .decode(type: Dictionary<String, String>.self, decoder: JSONDecoder())
            .sink(receiveCompletion: NetworkManager.handleCompletion) {[weak self] (response) in
                self?.spotifyVM?.getSpotifySong(songId: songId, completion: { spotifyTrack in
                    guard let spotifyTrack = spotifyTrack else {
                        print("Function: \(#function), line: \(#line),", "spotify track empty for id : \(songId)")
                        return
                    }
                    if lib.addSong(spotifySong: spotifyTrack) {
                        self?.addSongFromLib(songId: songId)
                    } else {
                        self?.appError = AppError(description: "Error adding \(spotifyTrack.name) to library")
                    }
                })
                
                guard let taskId = response["task_id"] else { return }
                self?.updateStatus(taskId: taskId, songId: songId)
                
                subscription?.cancel()
            }
        
        addSongFromLib(songId: songId)
    }
    
    func setIsDownloading() {
        for (_, status) in downloadProgress {
            if status.progress != 100 {
                downloadingSong = true
                return
            }
        }
        
        downloadingSong = false
    }
    
    func addSongFromLib(songId: String) {
        if let song = lib?.getSong(songId: songId) {
            if !isSongInLib(songId: songId) {
                print("Function: \(#function), line: \(#line),", "Adding \(String(describing: song.name)) to library")
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
        
        func removeSongfromLib(sId: String, complete: ((Error?) -> ())? = nil) {
            lib.update(didUpdate: { err in
                if let err = err {
                    self.appError = AppError(description: err.localizedDescription)
                    print("Function: \(#function), line: \(#line),", err)
                    return
                }
                self.songs.removeAll { song in
                    song.id == sId
                }
                
                if let complete = complete {
                    complete(nil)
                }
            })
        }
        
        if notifyServer {
            let url = URL(string: Config.SERVER + HttpRequests.REMOVE_SONG)!
            
            var subscription: AnyCancellable?
            subscription = NetworkManager.request(url: url, type: .POST, httpbody: try? JSONSerialization.data(withJSONObject: ["url" : songId]))
                .decode(type: Dictionary<String, String>.self, decoder: JSONDecoder())
                .sink(receiveCompletion: { fail in
                    switch fail {
                    case .failure(let e):
                        self.appError = AppError(description: e.localizedDescription)
                        print("Function: \(#function), line: \(#line),", e)
                        if let completion = completion {
                            completion(e)
                        }
                    case .finished:
                        break
                    }
                }, receiveValue: { (response) in
                    removeSongfromLib(sId: songId, complete: completion)
                    subscription?.cancel()
                })
        } else {
            removeSongfromLib(sId: songId, complete: completion)
        }
    }
    
    func restoreFromHistory(history: History) {
        songs = [Song]()
        for song in history.userLibrary {
            addSong(songId: song.id)
        }
    }
    
    func updateStatus(taskId: String, songId: String, tryNum: Int = 0) {
        if self.downloadProgress[songId]?.progress == 100 { return }
        
        if self.downloadProgress[songId] == nil {
            self.downloadProgress[songId] = TaskStatus.Status(progress: 10, description: "Waiting in queue")
        }
        
        let url = URL(string: Config.SERVER + HttpRequests.STATUS + "/" + taskId)!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Application/json", forHTTPHeaderField: "Content-Type")

        URLSession.shared.dataTask(with: request) { data, response, err in
            guard let data = data, err == nil else {
                if let err = err {
                    if err._code == -1001 {
                        if tryNum < 100 {
                            print("Function: \(#function), line: \(#line),", "Request timeout: trying again...")
                            self.updateStatus(taskId: taskId, songId: songId, tryNum: tryNum + 1)
                            return
                        }
                    }
                }
                DispatchQueue.main.async {
                    self.appError = AppError(description: err?.localizedDescription)
                    print("Function: \(#function), line: \(#line),", err as Any)
                    self.downloadProgress[songId] = nil
                    self.removeSong(songId: songId)
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
                            lib.update(didUpdate: { err in
                                if let err = err {
                                    self.appError = AppError(description: err.localizedDescription)
                                    print("Function: \(#function), line: \(#line),", err)
                                    return
                                }
                                if let song = lib.getSong(songId: songId) {
                                    self.replaceDummy(song: song)
                                }
                            })
                        }
                        
                        DispatchQueue.main.async {
                            self.setIsDownloading()
                        }
                        
                    default:
                        print("Function: \(#function), line: \(#line),", "Request Status: \(stat.rawValue)")
                    }
                }
                
            } catch let err {
                print("Function: \(#function), line: \(#line),", "Error decoding task status: ", err)
                print("Function: \(#function), line: \(#line),", "trying again...")
                DispatchQueue.main.async {
                    if tryNum < 3 {
                        self.updateStatus(taskId: taskId, songId: songId, tryNum: tryNum + 1)  //  Recursive call
                    } else {
                        self.appError = AppError(description: err.localizedDescription)
                        print("Function: \(#function), line: \(#line),", err)
                        self.downloadProgress[songId] = nil
                        self.removeSong(songId: songId)
                    }
                }
            }
            
        }.resume()
    }
}
