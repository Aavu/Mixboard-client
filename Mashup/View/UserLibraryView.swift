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
    
    let cardWidth: CGFloat
    
    @State var dragOffset = Dictionary<String, CGSize>()
    
    var body: some View {
        let ExpandedCardWidth: CGFloat = cardWidth + 120
        ZStack {
            RoundedRectangle(cornerRadius: 4).foregroundColor(.SecondaryBgColor).shadow(radius: 16)
                .frame(width: mashup.isFocuingSongs ? ExpandedCardWidth + 6: cardWidth + 6)
                .ignoresSafeArea(edges: [.vertical])
            VStack {
                ZStack {
                    VStack {
                        ForEach(userLib.songs, id: \.self) { song in
                            UserLibSongCardView(song: song)
                                .frame(width: mashup.isFocuingSongs ? ExpandedCardWidth: cardWidth)
                                .frame(maxHeight: 150)
                                .offset(dragOffset[song.id] ?? .zero)
                                .environmentObject(userLib)
                                .gesture(DragGesture(coordinateSpace: .global)
                                    .onChanged({ value in
                                        withAnimation {
                                            dragOffset[song.id]?.width = min(0, value.translation.width)
                                        }
                                        
                                    })
                                         
                                    .onEnded({ value in
                                        if value.predictedEndLocation.x < 0 {
                                            userLib.removeSong(songId: song.id)
                                            mashup.deleteRegionsFor(songId: song.id)
                                            withAnimation {
                                                dragOffset[song.id] = value.predictedEndTranslation
                                            }
                                            
                                        } else {
                                            withAnimation {
                                                dragOffset[song.id] = .zero
                                            }
                                        }
                                    })
                                )
                                .onDrag {
                                    withAnimation {
                                        mashup.isFocuingSongs = false
                                    }
                                    return .init(contentsOf: URL(string: song.id))!
                                } preview: {
                                    SongCardView(song: song).frame(width: 72, height: 60).environmentObject(userLib)
                                }
                                .onTapGesture {
                                    withAnimation {
                                        mashup.isFocuingSongs.toggle()
                                    }
                                }
                                .onAppear {
                                    dragOffset[song.id] = .zero
                                }
                        }
                    }
                }
                
                
                if mashup.canDisplayLibrary {
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
                userLib.addSongs(songs: results)
            }
        }
        .onAppear {
            userLib.attachViewModels(library: library, spotifyViewModel: spotifyVM)
        }
        
    }
}

struct UserLibraryView_Previews: PreviewProvider {
    static var previews: some View {
        UserLibraryView(numSongs: 4, presentHistoryView: .constant(false), cardWidth: 144)
    }
}
