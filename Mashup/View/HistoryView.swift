//
//  HistoryView.swift
//  Mashup
//
//  Created by Raghavasimhan Sankaranarayanan on 10/18/22.
//

import SwiftUI

struct HistoryView: View {
    
    @EnvironmentObject var historyVM: HistoryViewModel
    @EnvironmentObject var mashupVM: MashupViewModel
    @EnvironmentObject var userLibVM: UserLibraryViewModel
    
    @Binding var presentHistoryView: Bool
    
    var body: some View {
        ZStack {
            Rectangle().foregroundColor(.BgColor)
            List {
                Section("Active") {
                    if let history = historyVM.current {
                        Text(historyVM.getDateString(history: history))
                    } else {
                        Text("No active sessions")
                    }
                }
                
                Section("History") {
                    ForEach(historyVM.histories, id: \.self) { history in
                        if history != historyVM.current {
                            Text(historyVM.getDateString(history: history))
                                .onTapGesture {
                                    mashupVM.restoreFromHistory(history: history)
                                    userLibVM.restoreFromHistory(history: history)
                                    historyVM.current = history
                                    
                                    withAnimation {
                                        presentHistoryView = false
                                    }
                                }
                        }
                    }
                }
            }
        }
    }
}

struct HistoryView_Previews: PreviewProvider {
    static var previews: some View {
        HistoryView(presentHistoryView: .constant(true))
    }
}
