//
//  History.swift
//  Mashup
//
//  Created by Raghavasimhan Sankaranarayanan on 10/18/22.
//

import Foundation
import FirebaseFirestoreSwift

struct History: Identifiable, Equatable, Codable {
    @DocumentID var id = UUID().uuidString
    var audio: Audio?
    let date: Date
    let userLibrary: [Song]
    let layout: Layout
    
    static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.id == rhs.id
    }
}
