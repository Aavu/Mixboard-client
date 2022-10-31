//
//  HistoryViewModel.swift
//  Mashup
//
//  Created by Raghavasimhan Sankaranarayanan on 10/18/22.
//

import Foundation

class HistoryViewModel: ObservableObject {
    @Published var histories = [History]()
    @Published var current: History?
    
    let formatter = DateFormatter()
    
    init() {
        formatter.timeStyle = .short
        formatter.dateStyle = .short
    }
    
    func add(history: History) {
        for h in histories {
            if h.id == history.id {
                return
            }
        }
        self.histories.append(history)
        print("History for '\(history.id)' saved!")
    }
    
    func isEmpty() -> Bool {
        return histories.isEmpty
    }
    
    func getDateString(history: History) -> String {
        return formatter.string(from: history.date)
    }
}
