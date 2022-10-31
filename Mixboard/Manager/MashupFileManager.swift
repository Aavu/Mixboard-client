//
//  FileManager.swift
//  Mashup
//
//  Created by Raghavasimhan Sankaranarayanan on 10/16/22.
//

import Foundation

class MashupFileManager {
    static func saveAudio(data: Data, name: String, ext: String) -> URL? {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent("\(name).\(ext)")
        do {
            try data.write(to: path)
            return path
        } catch let err {
            print(err)
        }
        
        return nil
    }
}
