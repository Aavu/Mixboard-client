//
//  UserLibraryView.swift
//  Mashup
//
//  Created by Raghavasimhan Sankaranarayanan on 10/13/22.
//

import SwiftUI

struct UserLibraryView: View {
    private let numSongs: Int
    
    @State var isPresented = false
    
    @EnvironmentObject var mashup: MashupViewModel
    @EnvironmentObject var library: LibraryViewModel
    @EnvironmentObject var userLib: UserLibraryViewModel
    
    private let cardWidth: CGFloat = 144
    private let ExpandedCardWidth: CGFloat = 264
    
    init(numSongs: Int, isPresented: Bool = false) {
        self.numSongs = numSongs
        self.isPresented = isPresented
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4).foregroundColor(.SecondaryBgColor).shadow(radius: 16).frame(width: mashup.isFocuingSongs ? ExpandedCardWidth + 6: cardWidth + 6)
            VStack {
                ForEach(userLib.songs, id: \.self) { song in
                    SongCardView(song: song)
                        .frame(width: mashup.isFocuingSongs ? ExpandedCardWidth: cardWidth)
                        .frame(maxHeight: 150)
                        .contextMenu {
                        Button {
                            userLib.removeSong(songId: song.id)
                        } label: {
                            Text("Remove")
                        }
                    }
                    .onDrag {
                        withAnimation {
                            mashup.isFocuingSongs = false
                        }
                        return .init(contentsOf: URL(string: song.id))!
                    } preview: {
                        SongCardView(song: song).frame(width: 72, height: 60)
                    }
                    .onTapGesture {
                        withAnimation {
                            mashup.isFocuingSongs.toggle()
                        }
                    }

                }
                
                if mashup.canDisplayLibrary {
                    if userLib.songs.count < 4 {
                        Button {
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
        }.sheet(isPresented: $isPresented) {
            LibraryView(isPresented: $isPresented) { results in
                userLib.addSongs(songs: results)
            }
        }
        .onAppear {
            userLib.attachLibrary(library: library)
        }
    }
}

struct UserLibraryView_Previews: PreviewProvider {
    static var previews: some View {
        UserLibraryView(numSongs: 4)
    }
}
