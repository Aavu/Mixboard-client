//
//  LuckyMeManager.swift
//  Mashup
//
//  Created by Raghavasimhan Sankaranarayanan on 10/20/22.
//

import Foundation

class LuckyMeManager {
    static let shared = LuckyMeManager()
    
    private var templates: LuckyMeTemplates?
    
    var appError: AppError?
    
    func loadTemplateFile() {
        guard let url = Bundle.main.url(forResource: "LuckyMeTemplates", withExtension: "json")
        else {
            appError = AppError(description: "LuckyMe templates JSON file not found")
            print("Function: \(#function), line: \(#line),", "LuckyMe templates JSON file not found")
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            self.templates = try JSONDecoder().decode(LuckyMeTemplates.self, from: data)
        } catch let e {
            print("Function: \(#function), line: \(#line),", e)
            appError = AppError(description: e.localizedDescription)
            return
        }
    }
    
    func surpriseMe(songs: [Song]) -> Layout? {
        var layout = Layout()
        guard let templates = templates else { return nil }
        guard let tracks = templates.tracks[songs.count] else { return nil }
        let shuffledSongs = songs.shuffled()
        let templateNum = tracks.count - 1
        
        let luck = tracks[Int.random(in: 0...templateNum)]
        
        for lane in Lane.allCases {
            layout.lane[lane.rawValue] = Layout.Track()
            let laneVars = luck.lane[Int(lane.rawValue)!]!
            
            for j in 0..<laneVars.blocks.count {
                let block = laneVars.blocks[j]
                let startPos = block[0]
                let width = block[1] - startPos
                
                let trackId = determineTrack(trackId: laneVars.tracks[j])
                let song = shuffledSongs[trackId]

                let region = Region(x: startPos, w: width, item: Region.Item(id: song.id))
                layout.lane[lane.rawValue]!.layout.append(region)
            }
        }
        
        return layout
    }
    
    private func getBlockWidth(lane: Lane, maxWidth: Int) -> Int {
        let randomWidth = [
            Lane.Vocals: Int.random(in: 4...maxWidth),
            Lane.Other: Int.random(in: 4...12),
            Lane.Bass: Int.random(in: 4...12),
            Lane.Drums: Int.random(in: 8...maxWidth)
        ]
        
        return randomWidth[lane]!
    }
    
    func findOverlap(x: Int, y: Int, song: Song, lane: Lane) ->Bool {
        
        return false
    }
    
    private func determineTrack(trackId: Int) -> Int {
        switch(trackId) {
        case 4:
            return Int.random(in: 0...1)
        case 5:
            return Int.random(in: 2...3)
        case 6:
            return Int.random(in: 0...3)
        default:
            return trackId
        }
    }
}
