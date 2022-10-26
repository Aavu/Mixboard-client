//
//  ToolbarView.swift
//  Mashup
//
//  Created by Raghavasimhan Sankaranarayanan on 10/13/22.
//

import SwiftUI

struct ToolbarView: View {
    @EnvironmentObject var mashupVM: MashupViewModel
    @EnvironmentObject var userLibVM: UserLibraryViewModel
    @EnvironmentObject var historyVM: HistoryViewModel
    var audioManager = AudioManager.shared
    
    @Binding var presentHistoryView: Bool
    
    var body: some View {
        ZStack(alignment: .top) {
            Rectangle().foregroundColor(.BgColor).ignoresSafeArea().shadow(radius: 8)
            HStack {
                Button {
                    handleShareBtn()
                } label: {
                    Image(systemName: "square.and.arrow.up").renderingMode(.template).foregroundColor(.SecondaryAccentColor).padding([.all], 16)
                }

                Spacer()
                
                Button {
                    mashupVM.surpriseMe(songs: userLibVM.songs)
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 4).frame(width: 128, height: 36)
                            .foregroundColor(.BgColor)
                            .shadow(radius:  4)

                        HStack {
                            Image(systemName: "shuffle").renderingMode(.template).foregroundColor(.SecondaryAccentColor)
                            Text("Surprise Me").foregroundColor(.SecondaryAccentColor)
                        }
                    }.padding([.all], 8)
                        .zIndex(1)
                        .opacity(userLibVM.songs.count > 0 ? 1 : 0)
                }
                
                
                Button {
                    mashupVM.clearCanvas()
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 4).frame(width: 120, height: 36)
                            .foregroundColor(.BgColor)
                            .shadow(radius:  4)
                        Text("Clear Canvas").foregroundColor(.red)
                    }
                    .padding([.all], 8)
                    .zIndex(1)
                    .opacity(mashupVM.isEmpty ? 0: 1)
                }

                Spacer()

                HStack {
                    // MARK: Backward 10 Button
                    Button {
                        audioManager.setProgress(progress: max(0, audioManager.progress - 0.1))
                    } label: {
                        Image(systemName: "gobackward.10").font(.title2).foregroundColor(.AccentColor).opacity(mashupVM.readyToPlay ? 1 : 0.5)
                    }
                    .disabled(!mashupVM.readyToPlay)
                    
                    // MARK: Play Button
                    Button {
                        handlePlayBtn()
                    } label: {
                        Image(systemName: audioManager.isPlaying ? "pause.fill" : "play.fill").font(.title).foregroundColor(.AccentColor).opacity(mashupVM.readyToPlay ? 1 : 0.5)
                    }
                    .disabled(!mashupVM.readyToPlay)
                    .padding([.leading, .trailing], 24)
                    
                    // MARK: Forward 10 Button
                    Button {
                        audioManager.setProgress(progress: min(1, audioManager.progress + 0.1))
                    } label: {
                        Image(systemName: "goforward.10").font(.title2).foregroundColor(.AccentColor).opacity(mashupVM.readyToPlay ? 1 : 0.5)
                    }
                    .disabled(!mashupVM.readyToPlay)
                }
                
                Spacer()
                
                // MARK: Generate Button
                Button {
                    let uuid = UUID()
                    mashupVM.sendGenerateRequest(uuid: uuid) { url, layout in
                        guard let url = url else { return }
                        let history = History(id: uuid, audioFilePath: url, date: Date(), userLibrary: userLibVM.songs, layout: layout)
                        historyVM.current = history
                        historyVM.add(history: history)
                    }
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 4).frame(width: 120, height: 36).foregroundColor(mashupVM.isEmpty ? .clear : .SecondaryAccentColor).shadow(radius:  4)
                        Text("Generate").foregroundColor(.BgColor)
                    }.offset(y: mashupVM.isEmpty ? 100.0 : 0.0)
                        .animation(.spring(), value: mashupVM.isEmpty)
                }.disabled(mashupVM.isGenerating || mashupVM.isEmpty)
                    .padding(.trailing, 4)
                
                Spacer()
                
                // MARK: History Button
                Button {
                    withAnimation {
                        presentHistoryView = true
                    }
                } label: {
                    Image("History")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(historyVM.isEmpty() ? .SecondaryBgColor : .AccentColor)
                }.padding()
                    .disabled(historyVM.isEmpty())
                
            }.padding(.top, 4)
        }
    }
    
    func handlePlayBtn() {
        if audioManager.isPlaying {
            audioManager.stop()
        } else {
            guard let audioFile = mashupVM.mashupAudioFile else {
                print("No Audio file available")
                return
            }
            audioManager.play(audioFile: audioFile)
        }
    }
    
    func handleShareBtn() {
        print("Clicked Share")
    }

}

//struct ToolbarView_Previews: PreviewProvider {
//    static var previews: some View {
//        ToolbarView()
//    }
//}
