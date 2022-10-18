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
    @Published var isPlaying = false

    private var displayLink: CADisplayLink?
    
    func play(audioFile: URL) {
        if let player {
            player.play()
            isPlaying = player.isPlaying
        } else {
            do {
                player = try AVAudioPlayer(contentsOf: audioFile)
                guard let player = player else { return }
                player.delegate = self
                player.play()
                isPlaying = player.isPlaying
            } catch let err {
                print(err)
            }
        }
        
        displayLink = CADisplayLink(target: self, selector: #selector(self.updateProgress))
        displayLink?.add(to: .current, forMode: .common)
    }
    
    func stop() {
        guard let player = player else { return }
        player.pause()
        displayLink?.invalidate()
        updateProgress()    // Just in case the timer is invalidated before the final update
        isPlaying = player.isPlaying
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
