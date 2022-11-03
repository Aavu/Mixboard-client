//
//  AudioManager.swift
//  Mashup
//
//  Created by Raghavasimhan Sankaranarayanan on 10/17/22.
//

import Foundation
import AVKit
import Combine

class AudioManager: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var player: AVAudioPlayer?
    @Published var progress: Double = 0
    @Published var isPlaying: Bool = false
    @Published var currentAudio: Audio?
    
    @Published var appError: AppError?

    private var displayLink: CADisplayLink?
    
    static let shared = AudioManager()
    
    func play(audio: Audio) {
        if let player {
            if currentAudio == audio {
                player.play()
                isPlaying = player.isPlaying
            } else {
                playNewAudio(audio: audio)
            }
        } else {
            playNewAudio(audio: audio)
        }
        
        displayLink = CADisplayLink(target: self, selector: #selector(self.updateProgress))
        displayLink?.add(to: .current, forMode: .common)
    }
    
    private func playNewAudio(audio: Audio) {
        do {
            player?.stop()
            
            try AVAudioSession.sharedInstance().setCategory(.playback)
            
            player = try AVAudioPlayer(contentsOf: audio.file)
            guard let player = player else { return }
            player.delegate = self
            player.play()
            currentAudio = audio
            isPlaying = player.isPlaying
        } catch let err {
            print(err)
        }
    }
    
    func stop() {
        guard let player = player else { return }
        player.pause()
        displayLink?.invalidate()
        updateProgress()    // Just in case the timer is invalidated before the final update
        
        isPlaying = player.isPlaying
    }
    
    func reset() {
        stop()
        progress = 0
        currentAudio = nil
        player = nil
    }
    
    @objc func updateProgress() {
        guard let player = self.player else { return }
        
        if (player.duration > 0) {
            progress = player.currentTime / player.duration
        }
    }
    
    func setProgress(progress: CGFloat) {
        guard let player = self.player else { return }
        
        player.currentTime = progress * player.duration
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
    }
    
    
}
