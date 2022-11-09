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
    
    @ObservedObject var audioManager = AudioManager.shared
    
    @Binding var presentHistoryView: Bool
    
    var body: some View {
        ZStack(alignment: .top) {
            Rectangle().foregroundColor(.BgColor).shadow(radius: 8)
            HStack {
                if let audio = audioManager.currentAudio {
                    ShareLink(item: audio, preview: SharePreview("Share"))
                        .padding([.all], 16)
                }

                Spacer()
                
                Button {
                    if audioManager.isPlaying { return }
                    mashupVM.surpriseMe(songs: userLibVM.songs)
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 4).frame(width: 136, height: 36)
                            .foregroundColor(.BgColor)
                            .shadow(radius:  4)

                        HStack {
                            Image(systemName: "shuffle").renderingMode(.template).foregroundColor(.SecondaryAccentColor)
                            Text("Surprise Me").foregroundColor(.SecondaryAccentColor)
                        }
                    }.padding([.all], 8)
                        .zIndex(1)
                        .opacity(userLibVM.songs.count > 0 ? 1 : 0)
                        .opacity(audioManager.isPlaying ? 0.5 : 1)
                    
                }.disabled(mashupVM.isGenerating || audioManager.isPlaying)

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
                        Image(systemName: audioManager.player?.isPlaying ?? false ? "pause.fill" : "play.fill")
                            .font(.title).foregroundColor(.AccentColor).opacity(!mashupVM.isEmpty ? 1 : 0.5)
                    }
                    .disabled(mashupVM.isEmpty)
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
                
//                let generateBtnDisabled = mashupVM.isGenerating || mashupVM.isEmpty || audioManager.isPlaying
//                // MARK: Generate Button
//                Button {
//                    audioManager.reset()
//                    let uuid = UUID()
//                    mashupVM.sendGenerateRequest(uuid: uuid) { audio, layout in
//                        guard let audio = audio else { return }
//                        let history = History(id: uuid, audio: audio, date: Date(), userLibrary: userLibVM.songs, layout: layout)
//                        historyVM.current = history
//                        historyVM.add(history: history)
//                    }
//                } label: {
//                    ZStack {
//                        RoundedRectangle(cornerRadius: 4).frame(width: 120, height: 36).foregroundColor(mashupVM.isEmpty ? .clear : generateBtnDisabled ? .NeutralColor : .SecondaryAccentColor).shadow(radius:  4)
//                        Text("Generate").foregroundColor(.BgColor)
//                    }.offset(y: mashupVM.isEmpty ? 100.0 : 0.0)
//                        .animation(.spring(), value: mashupVM.isEmpty)
//                        .opacity(generateBtnDisabled ? 0.5 : 1)
//                }.disabled(generateBtnDisabled)
//                    .padding(.trailing, 4)
                
                Spacer()
                
                // MARK: History Button
                Button {
                    withAnimation {
                        presentHistoryView = true
                    }
                } label: {
                    Image(systemName: "person.crop.circle")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(.AccentColor)
                        .frame(width: 24)
                }.padding()
                
            }.padding(.top, 4)
        }
    }
    
    func handlePlayBtn() {
        func play() {
            if audioManager.isPlaying {
                audioManager.stop()
            } else {
                guard let audio = mashupVM.mashupAudio else {
                    print("Function: \(#function), line: \(#line),", "No Audio file available")
                    return
                }
                audioManager.play(audio: audio)
            }
        }
        
        if mashupVM.readyToPlay {   // Play
            play()
        } else {                    // Generate
            audioManager.reset()
            let uuid = UUID()
            mashupVM.sendGenerateRequest(uuid: uuid) { audio, layout in
                guard let audio = audio else { return }
                let history = History(id: uuid, audio: audio, date: Date(), userLibrary: userLibVM.songs, layout: layout)
                historyVM.current = history
                historyVM.add(history: history)
                play()
            }
        }
    }
}

//struct ToolbarView_Previews: PreviewProvider {
//    static var previews: some View {
//        ToolbarView()
//    }
//}
