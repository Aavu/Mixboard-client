//
//  ContentView.swift
//  Mashup
//
//  Created by Raghavasimhan Sankaranarayanan on 10/13/22.
//

import SwiftUI

struct MashupView: View {
    @StateObject var libViewModel = LibraryViewModel()
    @StateObject var userLibVM = UserLibraryViewModel()
    @StateObject var spotifyVM = SpotifyViewModel(numTracks: 20)
    @StateObject var mashupVM = MashupViewModel()
    @StateObject var audioManager = AudioManager()
    
    @StateObject var historyVM = HistoryViewModel()
    
    @State var audioProgress:CGFloat = 0
    @State var playHeadProgress: CGFloat = 0
    @State var presentHistoryView = false
    
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    var body: some View {
        GeometryReader() { geo in
            let historyWidth:CGFloat = 250
            ZStack {
                Color.BgColor.ignoresSafeArea()
                
                HStack(alignment: .center) {
                    UserLibraryView(numSongs: 4, presentHistoryView: $presentHistoryView, cardWidth: mashupVM.userLibCardWidth)
                        .zIndex(2)
                        .blur(radius: presentHistoryView ? 2:0)

                    ZStack {
                        VStack {
                            Spacer()
                            TracksView(audioProgress: $audioProgress, playHeadProgress: $playHeadProgress)
                                .cornerRadius(8)
                            Spacer(minLength: 16)
                            ToolbarView(audioManager: audioManager, presentHistoryView: $presentHistoryView)
                                .frame(height: horizontalSizeClass == .compact ? 32: 64)
                            
                        }.blur(radius: mashupVM.isFocuingSongs ? 4:0)
                            .onTapGesture {
                                if mashupVM.isFocuingSongs {
                                    withAnimation {
                                        mashupVM.isFocuingSongs = false
                                    }
                                }
                                
                                withAnimation {
                                    presentHistoryView = false
                                }
                            }
                    }.blur(radius: presentHistoryView ? 2:0)
                        .padding([.horizontal], 4)
                    
                    
                    if presentHistoryView {
                        HistoryView(presentHistoryView: $presentHistoryView)
                            .frame(width: historyWidth)
                            .transition(.move(edge: .trailing))
                            .onDisappear {
                                audioManager.stop()
                                playHeadProgress = 0
                            }
                    }
                }
                .offset(x: (presentHistoryView && horizontalSizeClass == .compact) ? -150 : 0)
                .disabled(mashupVM.isGenerating)
                .blur(radius: mashupVM.isGenerating ? 8: 0)
                .overlay(mashupVM.isGenerating ? .black.opacity(0.5) : .clear)
                .environmentObject(libViewModel)
                .environmentObject(userLibVM)
                .environmentObject(mashupVM)
                .environmentObject(spotifyVM)
                .environmentObject(historyVM)
                
                if mashupVM.isGenerating {
                    ProgressView("Generating Mashup", value: CGFloat(mashupVM.generationProgress), total: 100).padding()
                        .foregroundColor(.white)
                        .progressViewStyle(LinearProgressViewStyle(tint: .white))
                }
            }
            .onTapGesture {
                mashupVM.unselectAllRegions()
            }
            .onChange(of: audioManager.progress) { progress in
                audioProgress = progress
            }
            .onChange(of: playHeadProgress) { progress in
                audioManager.setProgress(progress: progress)
            }
            .alert(isPresented: $mashupVM.showError, error: mashupVM.appError, actions: {
                Button("Ok") {
                    mashupVM.appError = nil
                }
            })
            .alert(isPresented: $userLibVM.showError, error: userLibVM.appError, actions: {
                Button("Ok") {
                    userLibVM.appError = nil
                }
            })
            .onAppear {
                mashupVM.userLibCardWidth = geo.size.width * 0.20
            }
            .onChange(of: geo.size) { newValue in
                mashupVM.userLibCardWidth = geo.size.width * 0.20
            }
        }
    }
    
}

struct MashupView_Previews: PreviewProvider {
    static var previews: some View {
        MashupView()
    }
}
