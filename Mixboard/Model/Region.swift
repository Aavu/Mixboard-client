//
//  Region.swift
//  Mashup
//
//  Created by Raghavasimhan Sankaranarayanan on 10/16/22.
//

import Foundation

struct Region: Hashable, Codable, Identifiable {
    enum State: String, Codable {
        case New
        case Moved
        case Ready
    }
    
    struct Item: Hashable, Codable {
        let id: String
        var name: String? = nil
        var tempo: Float? = nil
        var artist: String? = nil
        var preview_url: String? = nil
        var img_url: String? = nil
        var release_date: String? = nil
        var hover_on_album: Bool? = nil
        var isPlaying: Bool? = nil
        var color: String? = nil
        var Class: String? = nil
        
        private enum CodingKeys: String, CodingKey {
            case id             = "songId"
            case name           = "songName"
            case tempo          = "songTempo"
            case artist         = "artistName"
            case preview_url    = "preview_url"
            case img_url        = "img_url"
            case release_date   = "release_date"
            case hover_on_album = "hover_on_album"
            case isPlaying      = "isPlaying"
            case color          = "color"
            case Class          = "class"
        }
    }
    
    var x: Int
    var y: Int? = nil
    var w: Int
    var h: Float? = nil
    var i: String? = nil
    var del: Bool? = nil
    var Class: [String]? = nil
    var item: Item
    var state: State
    let id = UUID()
    var audioPosition: Int64?
    
    private enum CodingKeys: String, CodingKey {
        case x       = "x"
        case y       = "y"
        case w       = "w"
        case h       = "h"
        case i       = "i"
        case del     = "del"
        case Class   = "class"
        case item    = "item"
        case id      = "id"
        case state   = "state"
        case audioPosition   = "audioPosition"
    }
}

struct Layout: Hashable, Codable {
    struct Track: Hashable, Codable {
        var name: String? = nil
        var layoutKey: String? = nil
        var id: String? = nil
        var mouseover: Bool? = nil
        var layout = [Region]()
    }
    
    var lane = Dictionary<String, Track>()
}

struct GenerateRequest: Hashable, Codable {
    let data: Dictionary<String, Layout.Track>
    let email: String
    let sessionId: String
    var lastSessionId: String? = nil
}
