//
//  History.swift
//  Mashup
//
//  Created by Raghavasimhan Sankaranarayanan on 10/18/22.
//

import Foundation

struct History: Identifiable, Hashable {
    let id: UUID
    let audioFilePath: URL
    let date: Date
    let userLibrary: [Song]
    let layout: Layout
}
