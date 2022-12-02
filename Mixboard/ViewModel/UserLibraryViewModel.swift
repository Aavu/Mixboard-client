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
    
    func addSongs(songIds: [String: SongSource]) {
        for (id, src) in songIds {
            addSong(songId: id, songSource: src)
        }
    }
    
    // TODO: Add songsource so that it doesnt call spotify api even if the song is in local library
    func addSong(songId: String, songSource: SongSource = .Library) {
        if isSongInUserLibrary(songId: songId) {
            print("Function: \(#function), line: \(#line),", "Info: Song already in library")
            return
        }
        
        canRemoveSong[songId] = false
        addPlaceholderSong(songId: songId)
        
        BackendManager.shared.addSong(songId: songId) { err in
            if let err = err {
                print("Function: \(#function), line: \(#line), Error:", err)
                self.appError = AppError(description: err.localizedDescription)
                return
            }
            
            if songSource == .Library {
                if self.addSongFromLib(songId: songId) {
                    self.canRemoveSong[songId] = true
                    self.isSelected[songId] = nil
                } else {
                    self.removeSong(songId: songId) { err in
                        print("Function: \(#function), line: \(#line),", err as Any)
                    }
                }
            } else {
                self.spotifyVM?.getSpotifySong(songId: songId, completion: {spotifyTrack in
                    guard let spotifyTrack = spotifyTrack else {
                        print("Function: \(#function), line: \(#line),", "spotify track empty for id : \(songId)")
                        return
                    }
                    
                    if let lib = self.lib {
                        if lib.addSong(spotifySong: spotifyTrack) {
                            self.addSongFromLib(songId: songId)
                        } else {
                            self.appError = AppError(description: "Error adding \(spotifyTrack.name) to library")
                            self.removePlaceholderSongs()
                        }
                        self.canRemoveSong[songId] = true
                        self.isSelected[songId] = nil
                    }
                })
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
            return
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
                songs[i] = song
                return true
            }
        }
        return false
    }
    
    @discardableResult func addSongFromLib(songId: String) -> Bool {
        if let song = lib?.getSong(songId: songId) {
            if !isSongInUserLibrary(songId: songId) {
                print("Function: \(#function), line: \(#line),", "Adding \(song.name ?? "song") to library")
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
            BackendManager.shared.removeSong(songId: songId) { err in
                if let err = err {
                    print("Function: \(#function), line: \(#line),", err)
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
