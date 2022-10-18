//
//  ContentView.swift
//  Mashup
//
//  Created by Raghavasimhan Sankaranarayanan on 10/13/22.
//

import SwiftUI

struct MashupView: View {
    private let userLibView = UserLibraryView(numSongs: 4)
    @StateObject var libViewModel = LibraryViewModel()
    @StateObject var userLibVM = UserLibraryViewModel()
    
    @StateObject var mashupVM = MashupViewModel()
    @StateObject var audioManager = AudioManager()
    
    @State var audioProgress:CGFloat = 0
    @State var playHeadProgress: CGFloat = 0
    
    @StateObject var vocalLaneVM = LaneViewModel(lane: .Vocals)
    @StateObject var otherLaneVM = LaneViewModel(lane: .Other)
    @StateObject var bassLaneVM = LaneViewModel(lane: .Bass)
    @StateObject var drumLaneVM = LaneViewModel(lane: .Drums)
    
    var body: some View {
        ZStack {
            Color.BgColor.ignoresSafeArea()

            HStack(alignment: .center, spacing: 0) {
                userLibView.padding(.trailing, 4).zIndex(2)
                ZStack {
                    VStack(spacing: 0) {
                        Spacer()
                        //                    Text("Mashup").multilineTextAlignment(.center).padding([.top, .bottom], 12.0).foregroundColor(.LavenderBlush).font(.title2).shadow(radius: 4)
                        TracksView(vocalLaneVM: vocalLaneVM, otherLaneVM: otherLaneVM, bassLaneVM: bassLaneVM, drumLaneVM: drumLaneVM, audioProgress: $audioProgress, playHeadProgress: $playHeadProgress)
                            .cornerRadius(8)
                            .padding(.trailing, 52)
                        
                        ToolbarView(audioManager: audioManager)
                            .frame(height: 48)
                        
                        Spacer()
                    }.blur(radius: mashupVM.isFocuingSongs ? 4:0)
                        .onTapGesture {
                            if mashupVM.isFocuingSongs {
                                withAnimation {
                                    mashupVM.isFocuingSongs = false
                                }
                            }
                        }
//                    if mashupVM.isFocuingSongs {
//                        Rectangle().foregroundColor(.black).opacity(0.5).blur(radius: 4)
//                            .border(.black, width: 5)
//                            .onTapGesture {
//                                print("tap tap")
//                            }
//                    }
                }
                
            }.ignoresSafeArea()
                .disabled(mashupVM.isGenerating)
                .blur(radius: mashupVM.isGenerating ? 8: 0)
                .overlay(mashupVM.isGenerating ? .black.opacity(0.5) : .clear)
                .environmentObject(libViewModel)
                .environmentObject(userLibVM)
                .environmentObject(mashupVM)
            if mashupVM.isGenerating {
                ProgressView("Generating Mashup", value: CGFloat(mashupVM.generationProgress), total: 100)
            }
        }
        .onChange(of: audioManager.progress) { progress in
            audioProgress = progress
        }
        .onChange(of: playHeadProgress) { progress in
            audioManager.setProgress(progress: progress)
        }
        
    }
}

struct MashupView_Previews: PreviewProvider {
    static var previews: some View {
        MashupView()
    }
}
