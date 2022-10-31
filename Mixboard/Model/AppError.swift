//
//  AppError.swift
//  Mashup
//
//  Created by Raghavasimhan Sankaranarayanan on 10/19/22.
//

import Foundation

struct AppError: Identifiable, LocalizedError {
    let id = UUID()
    let errorDescription: String?
    
    init(description: String?) {
        self.errorDescription = description
        print("AppError: \(self.errorDescription ?? "")")
    }
}
