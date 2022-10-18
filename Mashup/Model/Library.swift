//
//  Library.swift
//  Mashup
//
//  Created by Raghavasimhan Sankaranarayanan on 10/13/22.
//

import Foundation

struct NonSilentBounds: Codable, Hashable {
    let drums: Dictionary<String, [Float]>
    let vocals: Dictionary<String, [Float]>
    let other: Dictionary<String, [Float]>
    let bass: Dictionary<String, [Float]>
}

struct Song: Codable, Hashable {
    var album: String?
    var artist: String?
    var external_url: String?
    var fs: Int?
    let id: String
    var img_url: String?
    var key_and_mode: [Int]?
    var name: String?
    var non_silent_bounds: NonSilentBounds?
    var preview_url: String?
    var release_date: String?
    var tempo: Float?
}

struct Library: Decodable, Hashable {
    let version: String
    let statusCode: Int
    let items: Dictionary<String, Song>
}
