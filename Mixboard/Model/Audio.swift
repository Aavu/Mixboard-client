//
//  Audio.swift
//  Mashup
//
//  Created by Raghavasimhan Sankaranarayanan on 10/29/22.
//

import Foundation
import SwiftUI
import AVFoundation

struct Audio: Equatable, Hashable, Transferable, Codable {
    let file: URL
    var position: AVAudioFramePosition = 0
    var length: AVAudioFramePosition?
    var sampleRate: Double = 44100
    
    var tempo: Double = 120
    
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .audio) {
            SentTransferredFile($0.file)
        } importing: { received in
            do {
                let f = try AVAudioFile(forReading: received.file)
                return self.init(file: received.file, position: 0, length: f.length, sampleRate: f.processingFormat.sampleRate)
            } catch {
                print(error)
            }
            return self.init(file: received.file)
        }
        
        ProxyRepresentation(exporting: \.file)
    }
    
    func getId() -> String {
        return String(file.lastPathComponent.split(separator: ".")[0])
    }
    
    static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.getId() == rhs.getId()
    }
}
