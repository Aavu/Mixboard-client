//
//  ContentView.swift
//  Mashup
//
//  Created by Raghavasimhan Sankaranarayanan on 10/13/22.
//

import SwiftUI

struct MashupView: View {
    @EnvironmentObject var mashupVM: MashupViewModel
    
    @StateObject var libViewModel   = LibraryViewModel()
    @StateObject var userLibVM      = UserLibraryViewModel()
    @StateObject var spotifyVM      = SpotifyViewModel()
    @StateObject var userInfoVM     = UserInfoViewModel()
    
    var body: some View {
        NavigationSplitView(columnVisibility: $mashupVM.UserInfoViewVisibility) {
            UserInfoView() { history in
                userLibVM.restoreFromHistory(history: history)
                mashupVM.restoreFromHistory(history: history)
            }
            .toolbar(.hidden)
        } detail: {
            HomeView()
                .environmentObject(spotifyVM)
                .environmentObject(libViewModel)
                .toolbar(.hidden)
        }
        .navigationSplitViewStyle(.prominentDetail)
        .environmentObject(mashupVM)
        .environmentObject(userLibVM)
        .environmentObject(userInfoVM)
        .onAppear {
            mashupVM.attach(userInfoVM: userInfoVM, userLibVM: userLibVM)
        }
    }
}

struct HomeView: View {
    @StateObject var audioManager = AudioManager.shared
    
    @EnvironmentObject var mashupVM: MashupViewModel
    @EnvironmentObject var spotifyVM: SpotifyViewModel
    @EnvironmentObject var libViewModel: LibraryViewModel
    @EnvironmentObject var userLibVM: UserLibraryViewModel
    
    @ObservedObject var backend = BackendManager.shared
    
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    var body: some View {
        let showProgress = backend.isGenerating && mashupVM.showGenerationProgress
        ZStack {
            Color.BgColor.ignoresSafeArea()

            ZStack(alignment: .trailing) {
                VStack{
                    HStack(alignment: .center, spacing: 0) {
                        UserLibraryView(numSongs: 4, cardWidth: mashupVM.userLibCardWidth)
                            .zIndex(2)
                            .allowsHitTesting(!audioManager.isPlaying)

                        VStack {
                            Spacer(minLength: 8)
                            TracksView()
                                .cornerRadius(8)
                            Spacer(minLength: 8)

                        }.blur(radius: mashupVM.isFocuingSongs ? 4:0)
                            .onTapGesture {
                                if mashupVM.isFocuingSongs {
                                    withAnimation {
                                        mashupVM.isFocuingSongs = false
                                    }
                                }
                            }
                            .padding([.horizontal], 4)
                    }
                    ToolbarView()
                        .frame(height: horizontalSizeClass == .compact ? 32: 64)
                }
                .disabled(backend.isGenerating)
                .blur(radius: showProgress ? 8: 0)
                .overlay(showProgress ? .black.opacity(0.5) : .clear)
                .allowsHitTesting(!backend.isGenerating)
                .environmentObject(libViewModel)
                .environmentObject(spotifyVM)
                .simultaneousGesture(TapGesture()
                    .onEnded({
                        withAnimation {
                            mashupVM.unselectAllRegions()
                            mashupVM.isFocuingSongs = false
                            userLibVM.isSelected.removeAll()
                        }

                        mashupVM.UserInfoViewVisibility = .detailOnly
                    })
                )
            }
            .environmentObject(userLibVM)
            .environmentObject(mashupVM)
            
            
            if showProgress {
                if let status = backend.generationStatus {
                    ProgressView(status.description ?? "Generating Mashup", value: CGFloat(status.progress), total: 100).padding()
                        .foregroundColor(.white)
                        .progressViewStyle(LinearProgressViewStyle(tint: .white))
                }
            }
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
            if mashupVM.loggedIn {
                libViewModel.update(didUpdate: { err in
                    if let err = err {
                        if err._code == -1011 {
                            mashupVM.appError = AppError(description: "Server not responding. Please try again later")
                            mashupVM.appFailed = true
                        } else {
                            mashupVM.appError = AppError(description: err.localizedDescription)
                            print("Function: \(#function), line: \(#line),", err)
                        }

                    }
                })
            }
            mashupVM.userLibCardWidth = 250
        }
        .ignoresSafeArea(.keyboard)
    }
}

struct MashupView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
            .environmentObject(MashupViewModel())
    }
}
