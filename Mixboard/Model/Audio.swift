//
//  Audio.swift
//  Mashup
//
//  Created by Raghavasimhan Sankaranarayanan on 10/29/22.
//

import Foundation
import SwiftUI

struct Audio: Equatable, Hashable, Transferable {
    let file: URL
    
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .audio) {
            SentTransferredFile($0.file)
        } importing: { received in
            self.init(file: received.file)
        }
        
        ProxyRepresentation(exporting: \.file)
    }
}
