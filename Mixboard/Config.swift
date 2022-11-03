//
//  Config.swift
//  Mashup
//
//  Created by Raghavasimhan Sankaranarayanan on 10/14/22.
//

import Foundation       

struct Config {
    static let SERVER = "http://130.207.85.80"
}

struct HttpRequests {
    static let ROOT = "/"
    static let NEW_SESSION = "/newSession"
    static let CREATE_LIB = "/createLibrary"
    static let GENERATE = "/generate"
    static let ADD_SONG = "/addSong"
    static let REMOVE_SONG = "/removeSong"
    static let TRACK_LIST = "/requestTrackList"
    static let STATUS = "/requestStatus"
    static let RESULT = "/requestResult"
}
