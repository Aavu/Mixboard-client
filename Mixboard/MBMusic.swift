//
//  MBMusic.swift
//  Mixboard
//
//  Created by Raghavasimhan Sankaranarayanan on 11/18/22.
//

import Foundation
import AVFoundation

class MBMusic: Equatable {
    enum SetValueError {
        case Success
        case AudioNotFound
        case ValueNotUpdated
        case IllegalArgument
    }
    
    var audios = Set<Audio>()
    var tempo: Double
    
    init(audios: Set<Audio> = Set(), tempo: Double? = nil) {
        self.audios = audios
        self.tempo = tempo ?? 120.0
    }
    
    func getNumAudio() -> Int {
        return audios.count
    }
    
    func add(audio: Audio) {
        audios.insert(audio)
    }
    
    func remove(audio: Audio) {
        audios.remove(audio)
    }
    
    func removeById(id: UUID) {
        for audio in audios {
            if audio.getId() == id.uuidString {
                remove(audio: audio)
                return
            }
        }
    }
    
    func getCommon(music: MBMusic?) -> MBMusic {
        guard let music = music else {return self}
        return MBMusic(audios: audios.intersection(music.audios), tempo: tempo)
    }
    
    func setTempo(_ tempo: Double) {
        self.tempo = tempo
    }
    
    func update(for audioId: UUID, position: Int? = nil, length: Int? = nil) -> SetValueError {
        if position == nil && length == nil { return .IllegalArgument }
        
        var updated: SetValueError = .AudioNotFound
        
        for audio in audios {
            let id = audio.file.lastPathComponent.split(separator: ".")[0]
            if id == audioId.uuidString {
                var tempPos = audio.position
                let tempLen = audio.length
                
                if let position = position {
                    let pos = MBMusic.getInSamples(value: position, sampleRate: audio.sampleRate, tempo: audio.tempo)
                    remove(audio: audio)
                    add(audio: Audio(file: audio.file, position: pos, length: tempLen))
                    tempPos = pos
                    updated = .Success
                }
                
                if let length = length {
                    let len = MBMusic.getInSamples(value: length, sampleRate: audio.sampleRate, tempo: audio.tempo)
                    remove(audio: audio)
                    audios.update(with: Audio(file: audio.file, position: tempPos, length: len))
                    updated = .Success
                }
                
                if updated == .Success {
                    return updated
                }
            }
        }
        
        return updated
    }
    
    
    static func getInSamples(value: Int, sampleRate: Double, tempo: Double) -> AVAudioFramePosition {
        let valueInSec = Double(value) * 4 * 60 / tempo
        return AVAudioFramePosition(valueInSec * sampleRate)
    }
    
    static func == (lhs: MBMusic, rhs: MBMusic) -> Bool {
        let temp = lhs.audios.intersection(rhs.audios)
        return temp.count == lhs.audios.count && temp.count == rhs.audios.count
    }
}
