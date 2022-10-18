//
//  LibraryView.swift
//  Mashup
//
//  Created by Raghavasimhan Sankaranarayanan on 10/13/22.
//

import SwiftUI

struct LibraryView: View {
    
    @ObservedObject var spotifyVM = SpotifyViewModel(numTracks: 20)
    @ObservedObject var libraryVM = LibraryViewModel()
    
    @State var selectedSongId = [String: SongSource]()
    
    @State var inSelectionMode = false
    @State var freezeSelection = false
    
    @Binding var isPresented: Bool
    
    var didSelectSongs: (Dictionary<String, SongSource>) -> ()
    
    let gridItem = [GridItem(.adaptive(minimum: 250))]
    
    init(isPresented: Binding<Bool>, didSelectSongs: @escaping (Dictionary<String, SongSource>) -> ()) {
        UITabBar.appearance().barTintColor = UIColor(.NeutralColor)
        UITabBar.appearance().backgroundColor = UIColor(.SecondaryBgColor)
        self._isPresented = isPresented
        self.didSelectSongs = didSelectSongs
    }
    
    var body: some View {
            TabView{
                ZStack {
                    Color.BgColor.ignoresSafeArea()
                    VStack {
                        HStack {
                            Button {
                                isPresented = false
                            } label: {
                                Image(systemName: "xmark.square").padding(.leading, 16).font(.largeTitle).foregroundColor(.AccentColor)
                            }
                            Spacer()
                            Text("Library")
                                .padding([.top, .bottom], 16).font(.headline).offset(x: inSelectionMode ? 16 : -28).foregroundColor(.AccentColor)
                            Spacer()
                            if inSelectionMode {
                                Button {
                                    handleDoneBtn()
                                } label: {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8).foregroundColor(.NeutralColor)
                                        Text("Add").foregroundColor(.AccentColor)
                                    }.frame(width: 72, height: 32).shadow(radius: 2)
                                }.padding(.trailing, 16)
                            }
                        }.frame(height: 48)
                        SearchBarView(searchText: $libraryVM.searchText)
                        ScrollView {
                            LazyVGrid(columns: gridItem) {
                                ForEach(libraryVM.songs, id: \.self) { song in
                                    ZStack {
                                        SongCardView(song: song).frame(height: 100)
                                            .cornerRadius(8)
                                            .border((selectedSongId[song.id] != nil) ? Color.NeutralColor: .clear, width: 4)
                                            .overlay((freezeSelection && selectedSongId[song.id] == nil) ? .gray.opacity(0.75) : .clear)
                                            .blur(radius: (freezeSelection && selectedSongId[song.id] == nil) ? 2 : 0)
                                            .onTapGesture {
                                                handleTapGesture(id: song.id, songSource: .Library)
                                            }
                                    }
                                }
                            }
                        }.padding(.all, 8)
                    }
                }
                .tabItem() {
                    Text("Library").font(.headline)
                }
                
                ZStack {
                    Color.BgColor.ignoresSafeArea()
                    VStack {
                        HStack {
                            Button {
                                isPresented = false
                            } label: {
                                Image(systemName: "xmark.square").padding(.leading, 16).font(.largeTitle).foregroundColor(.AccentColor)
                            }
                            Spacer()
                            Text("Spotify")
                                .padding([.top, .bottom], 16).font(.headline).offset(x: inSelectionMode ? 16 : -28).foregroundColor(.AccentColor)
                            Spacer()
                            if inSelectionMode {
                                Button {
                                    handleDoneBtn()
                                } label: {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8).foregroundColor(.NeutralColor)
                                        Text("Add").foregroundColor(.AccentColor)
                                    }.frame(width: 72, height: 32).shadow(radius: 2)
                                }.padding(.trailing, 16)
                            }
                        }.frame(height: 48)
                        SearchBarView(searchText: $spotifyVM.searchText)
                        ScrollView {
                            LazyVGrid(columns: gridItem) {
                                ForEach(spotifyVM.songs, id: \.self) { song in
                                    ZStack {
                                        SongCardView(spotifySong: song).frame(height: 100)
                                            .cornerRadius(8)
                                            .border((selectedSongId[song.id] != nil) ? Color.NeutralColor: .clear, width: 4)
                                            .overlay((freezeSelection && selectedSongId[song.id] == nil) ? .gray.opacity(0.75) : .clear)
                                            .blur(radius: (freezeSelection && selectedSongId[song.id] == nil) ? 2 : 0)
                                            .onTapGesture {
                                                handleTapGesture(id: song.id, songSource: .Spotify)
                                            }
                                    }
                                    
                                }
                            }
                        }.padding(.all, 8)
                    }
                }.tabItem {
                    Text("Spotify").font(.headline)
                }
            }
            .accentColor(.NeutralColor)
    }
    
    func handleTapGesture(id: String, songSource: SongSource) {
        if selectedSongId[id] != nil {
            selectedSongId.removeValue(forKey: id)
        } else {
            if (selectedSongId.count < 4) {
                selectedSongId[id] = songSource
            }
        }
        
        withAnimation(.default) {
            freezeSelection = selectedSongId.count >= 4
            inSelectionMode = !selectedSongId.isEmpty
        }
    }
    
    func handleDoneBtn() {
        didSelectSongs(selectedSongId)
        isPresented = false
    }
}

//struct LibraryView_Previews: PreviewProvider {
//    static var previews: some View {
//        LibraryView()
//    }
//}
