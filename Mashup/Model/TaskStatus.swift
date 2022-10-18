//
//  TaskResult.swift
//  Mashup
//
//  Created by Raghavasimhan Sankaranarayanan on 10/17/22.
//

import Foundation

struct TaskResult: Codable {
    struct Result: Codable {
        let snd: String
        let tempo: Float
    }
    
    let task_result: Result
}

struct TaskStatus: Codable {
    struct Status: Codable {
        let progress: Int
    }
    
    let requestStatus: String
    let task_id: String
    let task_result: Status
}
