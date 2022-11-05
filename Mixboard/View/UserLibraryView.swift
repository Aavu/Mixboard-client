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
    
    @State var dragLocation = Dictionary<String, CGPoint>()
    
    @State var isDragging = Dictionary<String, Bool>()
    
    @State var removingSong = false
    
    var body: some View {
        let ExpandedCardWidth: CGFloat = cardWidth + 120
        
            ZStack {
                RoundedRectangle(cornerRadius: 4).foregroundColor(.SecondaryBgColor).shadow(radius: 16)
                    .frame(width: cardWidth + 6)
//                    .frame(width: mashup.isFocuingSongs ? ExpandedCardWidth + 6: cardWidth + 6)
                    .ignoresSafeArea(edges: [.vertical])
                
                VStack {
                    if userLib.songs.count > 0 {
                        Button {
                            handleRemoveAllSongs()
                        } label: {
                            ZStack {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 4).frame(height: 36)
                                        .foregroundColor(.BgColor)
                                        .shadow(radius:  4)
                                    Text("Remove all Songs").foregroundColor(.red)
                                }
                                .opacity(removingSong || userLib.downloadingSong || audioManager.isPlaying ? 0.5: 1)
                                
                                if removingSong {
                                    ProgressView()
                                }
                            }
                            .frame(width:cardWidth)
                            .padding([.all], 8)
                        }
                        .animation(.spring(), value: userLib.songs.count > 0)
                        .transition(.move(edge: .top))
                        .allowsHitTesting(!(removingSong || userLib.downloadingSong))
                    }

                    
                    ForEach(userLib.songs, id: \.self) { song in
                        ZStack {
                            if userLib.dragOffset[song.id]?.width ?? 0 > 0 {
                                UserLibSongCardView(song: song, canShowOverlay: false)
                                    .frame(width: cardWidth)
                            }
                            
                            UserLibSongCardView(song: song)
                                .frame(width: cardWidth)
//                                       (isDragging[song.id] ?? false) ? (8 * (mashup.tracksViewSize.width - 86) / CGFloat(MashupViewModel.TOTAL_BEATS)) : mashup.isFocuingSongs ? ExpandedCardWidth: cardWidth)
                                .frame(maxHeight: (isDragging[song.id] ?? false) ? mashup.tracksViewSize.height / 4 : nil)
                                .offset(userLib.dragOffset[song.id] ?? .zero)
                                .environmentObject(userLib)
                                .gesture(DragGesture(coordinateSpace: .global)
                                    .onChanged({ value in
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
                                                        if err != nil { return }
                                                        mashup.deleteRegionsFor(songId: song.id)
                                                        mashup.readyToPlay = false
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
                                                        mashup.readyToPlay = false
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

                if !mashup.appFailed {
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
                            Text("Connecting to Server")
                        }
                    }
                }
            }
            .padding([.top, .bottom], 16)
        }.sheet(isPresented: $isPresented) {
            LibraryView(isPresented: $isPresented, userLibSongs: $userLib.songs) { results in
                mashup.readyToPlay = false
                userLib.addSongs(songIds: results)
            }
        }
        .onAppear {
            userLib.attachViewModels(library: library, spotifyViewModel: spotifyVM)
        }
        .onTapGesture {
            withAnimation {
                mashup.isFocuingSongs = false
                userLib.isSelected.removeAll()
            }
        }
        
    }

    func handleRemoveAllSongs() {
        removingSong = true
        
        let numSongs = userLib.songs.count
        var removeCount = 0
        for song in userLib.songs {
            userLib.removeSong(songId: song.id) { err in
                if let err = err {
                    print("error removing song. \(err)")
                    removingSong = false
                }
                
                mashup.deleteRegionsFor(songId: song.id)
                
                removeCount += 1
                
                if removeCount == numSongs {
                    removingSong = false
                    mashup.isEmpty = true
                }
            }

        }
    }
}

struct UserLibraryView_Previews: PreviewProvider {
    static var previews: some View {
        UserLibraryView(numSongs: 4, presentHistoryView: .constant(false), cardWidth: 144)
    }
}
