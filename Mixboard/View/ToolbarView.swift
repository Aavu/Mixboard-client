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
    @EnvironmentObject var historyVM: UserInfoViewModel
    
    @ObservedObject var audioManager = AudioManager.shared
    @ObservedObject var backend = BackendManager.shared
    
    var body: some View {
        ZStack(alignment: .top) {
            Rectangle().foregroundColor(.BgColor).shadow(radius: 8)
            HStack {
                // MARK: UserInfo Button
                Button {
                    withAnimation {
//                        mashupVM.userInfoViewVisibility = .doubleColumn
                        historyVM.showUserInfo = true
                    }
                } label: {
                    Image(systemName: "person.crop.circle")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(.AccentColor)
                        .frame(width: 24)
                }.padding()

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
                    
                }.disabled(backend.isGenerating || audioManager.isPlaying || userLibVM.songs.count == 0)

                Spacer()

                HStack {
                    // MARK: Backward 10 Button
                    Button {
                        audioManager.setCurrentPosition(position: audioManager.currentPosition - (44100 * 10))
                    } label: {
                        Image(systemName: "gobackward.10").font(.title2).foregroundColor(.AccentColor).opacity(mashupVM.readyToPlay ? 1 : 0.5)
                    }
                    .disabled(!mashupVM.readyToPlay || mashupVM.isEmpty)
                    
                    // MARK: Play Button
                    Button {
                        handlePlayBtn()
                    } label: {
                        if backend.isGenerating {
                            ProgressView(value: CGFloat(backend.generationStatus?.progress ?? 50), total: 100).progressViewStyle(.circular)
                        } else {
                            Image(systemName: audioManager.isPlaying ? "pause.fill" : "play.fill")
                                .font(.title).foregroundColor(.AccentColor).opacity(!mashupVM.isEmpty ? 1 : 0.5)
                        }
                    }
                    .disabled(mashupVM.isEmpty || backend.isGenerating)
                    .padding([.leading, .trailing], 24)
                    
                    // MARK: Forward 10 Button
                    Button {
                        audioManager.setCurrentPosition(position: audioManager.currentPosition + (44100 * 10))
                    } label: {
                        Image(systemName: "goforward.10").font(.title2).foregroundColor(.AccentColor).opacity(mashupVM.readyToPlay ? 1 : 0.5)
                    }
                    .disabled(!mashupVM.readyToPlay || mashupVM.isEmpty)
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
                
                Spacer()
                
                
//                if let music = audioManager.currentMusic {
//                    ShareLink(item: audio, preview: SharePreview("Share"))
//                        .padding([.all], 16)
//                } else {
//                    Rectangle().fill(.clear).frame(width: 100)
//                }
            }.padding(.top, 4)
        }
    }
    
    func handlePlayBtn() {
        func play() {
            if audioManager.isPlaying {
                audioManager.playOrPause()
            } else {
                guard let music = audioManager.currentMusic else {
                    print("Function: \(#function), line: \(#line),", "No Audio file available")
                    return
                }
                
                audioManager.setMashupLength(lengthInBars: mashupVM.getLastBeat())
                audioManager.playOrPause(music: music)
            }
        }
        
        if mashupVM.readyToPlay {   // Play
            play()
        } else {                    // Generate
            audioManager.reset()
            let uuid = UUID().uuidString
            mashupVM.generateMashup(uuid: uuid, lastSessionId: historyVM.getLastSessionId()) {
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
