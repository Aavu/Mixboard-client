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
    
    var onCompletion: ((Bool) -> ())?
    
    var body: some View {
        ZStack {
            Rectangle().foregroundColor(.clear).ignoresSafeArea()
            
            VStack {
                List {
                    Section("Active") {
                        if let history = historyVM.current {
                            Text(historyVM.getDateString(history: history))
                                .onTapGesture {
                                    handleTap(history: history)
                                }
                        } else {
                            Text("No active sessions")
                        }
                    }
                    
                    Section("History") {
                        ForEach(historyVM.histories, id: \.self) { history in
                            if history.id != historyVM.current?.id {
                                Text(historyVM.getDateString(history: history))
                                    .onTapGesture {
                                        handleTap(history: history)
                                    }
                            }
                        }
                    }
                }
                Spacer()
                
                Rectangle().frame(height: 1).foregroundColor(.SecondaryBgColor).opacity(0.5).padding(.vertical, 4)
                Button {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        FirebaseManager.signOut()
                        
                        @AppStorage("email") var currentEmail: String?
                        currentEmail = nil
                        mashupVM.loggedIn = false
                    }
                    
                    
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 4).frame(width: 136, height: 36)
                            .foregroundColor(.SecondaryAccentColor)
                            .shadow(radius:  4)
                    
                    
                        Text("Sign Out").foregroundColor(.BgColor)
                    }
                }
                .padding()

            }
        }
    }
    
    func handleTap(history: History) {
        mashupVM.restoreFromHistory(history: history)
        userLibVM.restoreFromHistory(history: history)
        historyVM.current = history
        
        if let onCompletion = onCompletion {
            onCompletion(true)
        }
    }
}

struct HistoryView_Previews: PreviewProvider {
    static var previews: some View {
        HistoryView()
    }
}
