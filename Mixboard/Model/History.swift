//
//  History.swift
//  Mashup
//
//  Created by Raghavasimhan Sankaranarayanan on 10/18/22.
//

import Foundation

struct History: Identifiable, Hashable, Equatable {
    let id: UUID
    let audio: Audio
    let date: Date
    let userLibrary: [Song]
    let layout: Layout
}
