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
    
    var audios = [String: Audio]()
    var tempo: Double
    
    init(audios: [String: Audio]? = nil, tempo: Double? = nil) {
        self.audios = audios ?? [String : Audio]()
        self.tempo = tempo ?? 120.0
    }
    
    func getNumAudio() -> Int {
        return audios.count
    }
    
    func add(audio: Audio) {
        audios[audio.getId()] = audio
        tempo = audio.tempo
    }
    
    func remove(audio: Audio) {
        audios[audio.getId()] = nil
    }
    
    func remove(id: UUID) {
        audios[id.uuidString] = nil
    }
    
    func getCommon(music: MBMusic?) -> MBMusic {
        guard let music = music else {return self}
        
        let temp = getIntersection(items: music.audios)
        
        return MBMusic(audios: temp, tempo: tempo)
    }
    
    func getIntersection(items: [String: Audio]) -> [String: Audio] {
        var temp = [String: Audio]()
        for (id, _) in items {
            if let a = self.audios[id] {
                temp[id] = a
            }
        }
        return temp
    }
    
    func setTempo(_ tempo: Double) {
        self.tempo = tempo
    }
    
    func update(for audioId: UUID, position: Int? = nil, length: Int? = nil) -> SetValueError {
        if position == nil && length == nil { return .IllegalArgument }
        
        var updated: SetValueError = .AudioNotFound
        
        for (id, audio) in audios {
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
                    add(audio: Audio(file: audio.file, position: tempPos, length: len))
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
        let temp = lhs.getIntersection(items: rhs.audios)
        return temp.count == lhs.audios.count && temp.count == rhs.audios.count
    }
}
