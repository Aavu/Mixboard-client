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
    @Published var disableRemoveBtn = false
    
    /// This is for the songs
    @Published var isSelected = Dictionary<String, Bool>() {
        didSet {
            isFocuingSongs = isSelected.count > 0
        }
    }
    
    @Published var silenceOverlayText = Dictionary<String, String>()
    @Published var dragOffset = Dictionary<String, CGSize>()
    
    @Published var isFocuingSongs = false
    
    @Published var canRemoveSong = [String:Bool]()
    
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
    
    func unselectAllSongs() {
        isSelected.removeAll()
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
    
    func contains(songId: String) -> Bool {
        for song in songs {
            if song.id == songId {
                return true
            }
        }
        
        return false
    }
    
    func addSongs(songIds: [String: SongSource]) {
        for (id, _) in songIds {
            addSong(songId: id) { err in
                if let err = err {
                    self.appError = AppError(description: err.localizedDescription)
                    self.removePlaceholderSongs()
                }
            }
        }
    }
    
    func addSong(songId: String, completion: ((Error?) -> ())? = nil) {
        if isSongInUserLibrary(songId: songId) {
            Logger.info("Song already in library")
            return
        }
        
        canRemoveSong[songId] = false
        addPlaceholderSong(songId: songId)
        
        BackendManager.shared.addSong(songId: songId) { err in
            if let err = err {
                Logger.error(err)
                if let completion = completion {
                    completion(err)
                }
                return
            }
            
            if let lib = self.lib {
                lib.update() {err in
                    self.canRemoveSong[songId] = true
                    self.isSelected[songId] = nil
                    
                    if let err = err {
                        Logger.error(err)
                        if let completion = completion {
                            completion(err)
                        }
                        return
                    }
                    
                    if !self.addSongFromLib(songId: songId) {
                        if let completion = completion {
                            completion(BackendError.SongDownloadError)
                        }
                        return
                    }
                    
                }
            }
            
            if let completion = completion {
                completion(nil)
            }
        }
    }
    
    func addPlaceholderSong(songId: String) {
        if let song = lib?.getSong(songId: songId) {
            var placeHolderSong = song
            placeHolderSong.placeholder = true
            self.songs.append(placeHolderSong)
            return
        }
        
        if let song = spotifyVM?.getSong(songId: songId) {
            var placeHolderSong = song
            placeHolderSong.placeholder = true
            self.songs.append(placeHolderSong)
        }
    }
    
    func removePlaceholderSongs() {
        for i in (0..<songs.count) {
            if songs[i].placeholder {
                self.songs.remove(at: i)
            }
        }
    }
    
    func replaceDummy(song:Song) -> Bool {
        for i in (0..<songs.count) {
            if songs[i].id == song.id {
                Logger.trace("Replacing dummy for song id: \(song.id)")
                songs[i] = song
                return true
            }
        }
        return false
    }
    
    @discardableResult func addSongFromLib(songId: String) -> Bool {
        if let song = lib?.getSong(songId: songId) {
            if !isSongInUserLibrary(songId: songId) {
                Logger.info("Adding \(song.name ?? "song") to library")
                if self.replaceDummy(song: song) {
                    return true
                }
            }
        }
        
        return false
    }
    
    func isSongInUserLibrary(songId: String) -> Bool {
        for s in self.songs {
            if s.id == songId && !s.placeholder {
                return true
            }
        }
        
        return false
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
    
    func removeSong(songId: String, notifyServer: Bool = true, completion: @escaping (Error?) -> ()) {
        guard let lib = self.lib else { return }
        
        if let canRemove = canRemoveSong[songId], !canRemove {
            completion(MBError.SongStillDownloading)
            return
        }
        
        func removeSongfromLib(sId: String, complete: ((Error?) -> ())? = nil) {
            lib.update(didUpdate: { err in
                if let err = err {
                    self.appError = AppError(description: err.localizedDescription)
                    Logger.error(err)
                    return
                }
                
                var temp = [Song]()
                for song in self.songs {
                    if song.id != sId {
                        temp.append(song)
                    } else {
                        if song.placeholder {
                            if let complete = complete {
                                complete(MBError.RemoveError)
                                temp.append(song)
                            }
                        }
                    }
                }
                
                self.songs = temp
                if let complete = complete {
                    complete(nil)
                }
            })
        }
        
        if notifyServer {
            BackendManager.shared.removeSong(songId: songId) { err in
                if let err = err {
                    Logger.error(err)
                    self.appError = AppError(description: err.localizedDescription)
                    return
                }
                
                removeSongfromLib(sId: songId, complete: completion)
            }
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
    
    func shouldDisableRemove() -> Bool {
        for (_, canRemove) in canRemoveSong {
            if !canRemove {
                return true
            }
        }
        
        return false
    }
}
