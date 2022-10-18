//
//  SongCardViewModel.swift
//  Mashup
//
//  Created by Raghavasimhan Sankaranarayanan on 10/18/22.
//

import Foundation
import Combine

class SongCardViewModel: ObservableObject {
    @Published var downloadProgress: Int = 0
    
    static let TOTAL_PROGRESS = 100
    
    private var cancellable: AnyCancellable?
    
    private var userLibVM: UserLibraryViewModel
    private var song: Song?
    private var spotifySong: Spotify.Track?
    
    init(userLibVM: UserLibraryViewModel, spotifySong: Spotify.Track?) {
        self.userLibVM = userLibVM
        self.spotifySong = spotifySong
        addSubscribers()
    }
    
    init(userLibVM: UserLibraryViewModel, song: Song?) {
        self.userLibVM = userLibVM
        self.song = song
        addSubscribers()
    }
    
    func addSubscribers() {
        cancellable = userLibVM.$downloadProgress
                        .sink(receiveValue: { [weak self] (progress) in
                            print(progress)
                            for (id, p) in progress {
                                if id == self?.spotifySong?.id {
                                    self?.downloadProgress = p
                                    return
                                }
                            }
                        })
    }
    
}
