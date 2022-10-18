//
//  ToolbarView.swift
//  Mashup
//
//  Created by Raghavasimhan Sankaranarayanan on 10/13/22.
//

import SwiftUI

struct ToolbarView: View {
    
    @EnvironmentObject var mashupVM: MashupViewModel
    @ObservedObject var audioManager: AudioManager
    
    var body: some View {
        ZStack {
            Rectangle().foregroundColor(.BgColor).ignoresSafeArea().shadow(radius: 8)
            HStack {
//                Button {
//                    handleShareBtn()
//                } label: {
//                    Image(systemName: "square.and.arrow.up").font(.title).foregroundColor(.RaisinBlack).padding(.leading, 32)
//                }
                
                Spacer()

                Button {
                } label: {
                    Image(systemName: "gobackward.10").font(.title2).foregroundColor(.AccentColor).opacity(mashupVM.readyToPlay ? 1 : 0.5)
                }
                .disabled(!mashupVM.readyToPlay)
                
                Button {
                    handlePlayBtn()
                } label: {
                    Image(systemName: audioManager.isPlaying ? "pause.fill" : "play.fill").font(.title).foregroundColor(.AccentColor).opacity(mashupVM.readyToPlay ? 1 : 0.5)
                }
                .disabled(!mashupVM.readyToPlay)
                .padding([.leading, .trailing], 24)
                
                Button {
                } label: {
                    Image(systemName: "goforward.10").font(.title2).foregroundColor(.AccentColor).opacity(mashupVM.readyToPlay ? 1 : 0.5)
                }
                .disabled(!mashupVM.readyToPlay)
                
                Spacer(minLength: 100)
                
//                Button {
//                    handleLuckyMeBtn()
//                } label: {
//                    ZStack {
//                        RoundedRectangle(cornerRadius: 4).frame(width: 150, height: 36).foregroundColor(mashupVM.isEmpty ? .clear : .Thistle).shadow(radius:  4)
//                        if !mashupVM.isEmpty {
//                            HStack {
//                                Image(systemName: "shuffle").font(.headline).foregroundColor(.RaisinBlack)
//                                Text("Surprise Me").foregroundColor(.RaisinBlack)
//                                if mashupVM.isGenerating {
//                                    ProgressView()
//                                }
//                            }
//                        }
//                    }
//                }.disabled(mashupVM.isGenerating || mashupVM.isEmpty)
                
                Button {
                    handleGenerateBtn()
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 4).frame(width: 150, height: 36).foregroundColor(mashupVM.isEmpty ? .clear : .SecondaryAccentColor).shadow(radius:  4)
                        if !mashupVM.isEmpty {
                            HStack {
                                Text("Generate").foregroundColor(.BgColor)
                                if mashupVM.isGenerating {
                                    ProgressView()
                                }
                            }
                        }
                    }
                }.disabled(mashupVM.isGenerating || mashupVM.isEmpty)
                
                Spacer()
                
                Button {
                } label: {
                    ZStack {
                        Image(systemName: "line.3.horizontal.circle").font(.title).foregroundColor(.SecondaryAccentColor)
                    }
                }.padding()
                
            }
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
    
    func handleGenerateBtn() {
        mashupVM.sendGenerateRequest()
        
    }

}

//struct ToolbarView_Previews: PreviewProvider {
//    static var previews: some View {
//        ToolbarView(, audioManager: <#AudioManager#>)
//    }
//}
