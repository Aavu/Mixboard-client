//
//  UserLibraryView.swift
//  Mashup
//
//  Created by Raghavasimhan Sankaranarayanan on 10/13/22.
//

import SwiftUI

struct UserLibraryView: View {
    let numSongs: Int
    
    @State var isPresented = false
    @Binding var presentHistoryView: Bool
    
    @EnvironmentObject var mashup: MashupViewModel
    @EnvironmentObject var library: LibraryViewModel
    @EnvironmentObject var spotifyVM: SpotifyViewModel
    @EnvironmentObject var userLib: UserLibraryViewModel
    
    @ObservedObject var audioManager = AudioManager.shared
    
    let cardWidth: CGFloat
    
//    @State var dragOffset = Dictionary<String, CGSize>()
    @State var dragLocation = Dictionary<String, CGPoint>()
    
    @State var isDragging = Dictionary<String, Bool>()
    
    var body: some View {
        let ExpandedCardWidth: CGFloat = cardWidth + 120
            ZStack {
                RoundedRectangle(cornerRadius: 4).foregroundColor(.SecondaryBgColor).shadow(radius: 16)
                    .frame(width: mashup.isFocuingSongs ? ExpandedCardWidth + 6: cardWidth + 6)
                    .ignoresSafeArea(edges: [.vertical])
                
                VStack {
                    ForEach(userLib.songs, id: \.self) { song in
                        ZStack {
                            if userLib.dragOffset[song.id]?.width ?? 0 > 0 {
                                UserLibSongCardView(song: song, canShowOverlay: false)
                                    .frame(width: cardWidth)
                            }
                            
                            UserLibSongCardView(song: song)
                                .frame(width: (isDragging[song.id] ?? false) ? (8 * (mashup.tracksViewSize.width - 86) / CGFloat(MashupViewModel.TOTAL_BEATS)) : mashup.isFocuingSongs ? ExpandedCardWidth: cardWidth)
                                .frame(maxHeight: (isDragging[song.id] ?? false) ? mashup.tracksViewSize.height / 4 : nil)
                                .offset(userLib.dragOffset[song.id] ?? .zero)
                            
                                .environmentObject(userLib)
                                .gesture(DragGesture(coordinateSpace: .global)
                                    .onChanged({ value in
                                        if audioManager.isPlaying { return }
                                        dragLocation[song.id] = value.location
                                        isDragging[song.id] = true
                                        let lane = mashup.getLaneForLocation(location: dragLocation[song.id]!)
                                        if let lane = lane {
                                            if !userLib.hasNonSilentBoundsFor(song: song, lane: lane) {
                                                withAnimation {
                                                    userLib.silenceOverlayText[song.id] = "No \(lane.getName()) in song"
                                                }
                                            } else {
                                                withAnimation {
                                                    userLib.silenceOverlayText[song.id] = nil
                                                }
                                            }
                                            
                                            
                                        }
                                        withAnimation {
                                            userLib.dragOffset[song.id] = value.translation
                                        }
                                        
                                    })
                                         
                                    .onEnded({ value in
                                        if audioManager.isPlaying { return }
                                        isDragging[song.id] = false
                                        
                                        if value.predictedEndLocation.x < 0 {
                                            var shouldRemove = true
                                            withAnimation(.linear(duration: 0.25)) {
                                                if userLib.downloadProgress[song.id]?.progress != 100 {
                                                    userLib.dragOffset[song.id] = .zero
                                                    shouldRemove = false
                                                } else {
                                                    userLib.dragOffset[song.id] = value.predictedEndTranslation
                                                }
                                            }
                                            
                                            
                                            if shouldRemove {
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                                    userLib.removeSong(songId: song.id) { err in
                                                        userLib.dragOffset[song.id] = nil
                                                        guard err != nil else { return }
                                                        mashup.deleteRegionsFor(songId: song.id)
                                                    }
                                                }
                                            }
                                            
                                        } else {
                                            var success = false
                                            let lane = mashup.getLaneForLocation(location: dragLocation[song.id]!)
                                            if let lane = lane {
                                                if userLib.hasNonSilentBoundsFor(song: song, lane: lane) {
                                                    success = mashup.handleDropRegion(songId: song.id, dropLocation: dragLocation[song.id]!)
                                                    dragLocation[song.id]? = .zero
                                                    if success {
                                                        userLib.dragOffset[song.id] = .zero
                                                    }
                                                }
                                            }
                                            
                                            if !success {
                                                withAnimation {
                                                    userLib.silenceOverlayText[song.id] = nil
                                                    userLib.dragOffset[song.id] = .zero
                                                }
                                                HapticManager.shared.notify(type: .error)
                                            }
                                        }
                                    })
                                )
                                .simultaneousGesture(TapGesture()
                                    .onEnded({ value in
                                        if audioManager.isPlaying { return }
                                        withAnimation {
                                            mashup.isFocuingSongs.toggle()
                                        }
                                    })
                                )
                                .onAppear {
                                    userLib.dragOffset[song.id] = .zero
                                }
                        }
                }
                
                
                if mashup.canDisplayLibrary {
                    Spacer()
                    if userLib.songs.count < numSongs {
                        Button {
                            withAnimation {
                                presentHistoryView = false
                            }
                            
                            isPresented.toggle()
                        } label: {
                            VStack {
                                Image(systemName: "plus.circle").foregroundColor(.AccentColor).padding(.all, 4).font(.title)
                                Text("Add Songs").foregroundColor(.AccentColor).font(.subheadline)
                            }
                        }
                    }
                } else {
                    ProgressView {
                        Text("Preparing App")
                    }
                }
            }
            .padding([.top, .bottom], 16)
        }.sheet(isPresented: $isPresented) {
            LibraryView(isPresented: $isPresented, userLibSongs: $userLib.songs) { results in
                userLib.addSongs(songIds: results)
            }
        }
        .onAppear {
            userLib.attachViewModels(library: library, spotifyViewModel: spotifyVM)
        }
        .onTapGesture {
            if audioManager.isPlaying { return }
            withAnimation {
                mashup.isFocuingSongs = false
                userLib.isSelected.removeAll()
            }
        }
        
    }
}

struct UserLibraryView_Previews: PreviewProvider {
    static var previews: some View {
        UserLibraryView(numSongs: 4, presentHistoryView: .constant(false), cardWidth: 144)
    }
}
