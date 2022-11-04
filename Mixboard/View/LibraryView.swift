//
//  LibraryView.swift
//  Mashup
//
//  Created by Raghavasimhan Sankaranarayanan on 10/13/22.
//

import SwiftUI

struct LibraryView: View {
    
    @EnvironmentObject var spotifyVM: SpotifyViewModel
    @EnvironmentObject var libraryVM: LibraryViewModel
    
    @Binding var userLibSongs: [Song]
    
    @State var selectedSongId = [String: SongSource]()
    
    @State var inSelectionMode = false
    @State var freezeSelection = false
    
    @Binding var isPresented: Bool
    
    @State var selectedTab: Int = 0
    
    @State var draggingOffsetWidth: CGFloat = 0
    
    var didSelectSongs: ([String: SongSource]) -> ()
    
    let gridItem = [GridItem(.adaptive(minimum: 250))]
    
    init(isPresented: Binding<Bool>,userLibSongs: Binding<[Song]>, didSelectSongs: @escaping ([String: SongSource]) -> ()) {
        self._isPresented = isPresented
        self.didSelectSongs = didSelectSongs
        self._userLibSongs = userLibSongs
    }
    
    var body: some View {
        VStack(spacing: 0) {
            TabBarView(isPresented: $isPresented, selectedSongId: $selectedSongId, searchText: selectedTab == 0 ? $libraryVM.searchText : $spotifyVM.searchText, handleDoneBtn: handleDoneBtn) {
                ZStack {
                    RoundedRectangle(cornerRadius: 32).fill(Color.SecondaryBgColor).shadow(radius: 4).padding(4)
                    HStack(spacing: 0) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 32).foregroundColor(.BgColor).frame(width: 120).padding(8)
                                .offset(x: selectedTab == 0 ? -60 : 60)
                             
                            HStack(spacing: 32) {
                                Button {
                                    withAnimation {
                                        selectedTab = 0
                                    }
                                } label: {
                                    HStack {
                                        Image("MusicLib").renderingMode(.template).resizable().scaledToFit().padding(.vertical, 14)
                                        Text("Library")
                                    }
                                }
                                
                                Button {
                                    withAnimation {
                                        selectedTab = 1
                                    }
                                } label: {
                                    HStack {
                                        Image("Spotify").renderingMode(.original).resizable().scaledToFit().padding(.vertical, 14)
                                        Text("Spotify")
                                    }
                                }
                            }
                        }
                        ZStack {
                            
                        }
                    }
                }
                .frame(width: 256)
            
            }.frame(height: 100)
            
            if selectedSongId.count > 0 {
                SelectionView(selectedSongs: $selectedSongId)
                    .frame(height: 32)
                    .padding([.horizontal], 8)
                    .padding(.bottom, 16)
                    .animation(.spring(), value: selectedSongId.count > 0)
                    .transition(.move(edge: SwiftUI.Edge.bottom))
            }
            
            GeometryReader { geo in
                HStack(spacing: 0) {
                    LibContentView {
                        ForEach(libraryVM.songs, id: \.self) { song in
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
                    .frame(width: geo.frame(in: .global).width)
                    .opacity(selectedTab == 0 ? 1 : 0)
                    .onAppear {
                        libraryVM.filterUserLibSongs(songs: userLibSongs)
                    }
                    .animation(.spring(), value: selectedSongId.count > 0)
                    .transition(.move(edge: .bottom))
                    
                    LibContentView {
                        ForEach(spotifyVM.songs, id: \.self) { song in
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
                    .frame(width: geo.frame(in: .global).width)
                    .opacity(selectedTab == 1 ? 1 : 0)
                    .animation(.spring(), value: selectedSongId.count > 0)
                    .transition(.move(edge: .bottom))
                }
                .offset(x: (selectedTab == 0 ? 0: -geo.frame(in: .global).width) + draggingOffsetWidth)
                .gesture(DragGesture()
                    .onEnded({ value in
                        withAnimation(.spring()) {
                            if value.predictedEndTranslation.width < 0 {
                                selectedTab = 1
                            }
                            
                            else if value.predictedEndTranslation.width > geo.frame(in: .global).width {
                                selectedTab = 0
                            }
                        }
                        
                        draggingOffsetWidth = 0
                    })
                )
            }
        }
        .onAppear {
            spotifyVM.getRecommendations(numTracks: 20)
        }
        .onChange(of: selectedSongId) { newValue in
            withAnimation {
                freezeSelection = (selectedSongId.count + userLibSongs.count) >= 4
                inSelectionMode = !selectedSongId.isEmpty
            }
        }
    }
    
    func handleTapGesture(id: String, songSource: SongSource) {
        if selectedSongId[id] != nil {
            selectedSongId.removeValue(forKey: id)
        } else {
            if (selectedSongId.count < 4) {
                selectedSongId[id] = songSource
            }
        }
    }
    
    func handleDoneBtn() {
        var choices = selectedSongId
        if selectedSongId.isEmpty {    // Choose randomly
            let songs = libraryVM.songs.choose(max(0, 4 - (selectedSongId.count + userLibSongs.count)))
            for song in songs {
                choices[song.id] = .Library
            }
        }
        didSelectSongs(choices)
        isPresented = false
    }
}

struct SelectionView: View {
    @EnvironmentObject var spotifyVM: SpotifyViewModel
    @EnvironmentObject var libraryVM: LibraryViewModel
    
    @Binding var selectedSongs: [String: SongSource]
    
    @State var libSongs = [Song]()
    @State var spotifySongs = [Spotify.Track]()
    
    var body: some View {
        ZStack {
            
            RoundedRectangle(cornerRadius: 4).fill(Color.BgColor).shadow(radius: 4)
            HStack {
                HStack {
                    GeometryReader { geo in
                        HStack {
                            ForEach(libSongs, id: \.self.id) { song in
                                SongCardView(song: song)
                                    .frame(minWidth: 100)
                                    .frame(width: geo.size.width / 4)
                                    .cornerRadius(4)
                                    .onTapGesture {
                                        selectedSongs.removeValue(forKey: song.id)
                                    }
                            }
                            
                            ForEach(spotifySongs, id: \.self.id) { song in
                                SongCardView(spotifySong: song)
                                    .frame(minWidth: 100)
                                    .frame(width: geo.size.width / 4)
                                    .cornerRadius(4)
                                    .onTapGesture {
                                        selectedSongs.removeValue(forKey: song.id)
                                    }
                            }
                        }
                    }
                    
                    Spacer(minLength: 32)
                    
                    Button {
                        selectedSongs = [:]
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8).foregroundColor(.BgColor).shadow(radius: 4)
                            Text("Clear").foregroundColor(.red)
                        }.frame(width: 64)
                    }
                    
                }
            }
        }
        .onAppear {
            populateSongs()
        }
        .onChange(of: selectedSongs) { _ in
            populateSongs()
        }
    }
    
    func populateSongs() {
        libSongs = []
        spotifySongs = []
        
        for (songId, src) in selectedSongs {
            switch src {
            case .Spotify:
                spotifyVM.getSpotifySong(songId: songId) { spotifyTrack in
                    if let song = spotifyTrack {
                        print(song.id)
                        spotifySongs.append(song)
                    }
                }
            case .Library:
                if let song = libraryVM.getSong(songId: songId) {
                    libSongs.append(song)
                }
            }
        }
        print(selectedSongs.keys)
    }
}

struct LibContentView<T: View>: View {

    let content: T
    
    init(@ViewBuilder content: () -> T) {
        self.content = content()
    }
    
    let gridItem = [GridItem(.adaptive(minimum: 250))]
    
    var body: some View {
        ZStack {
            Color.BgColor.ignoresSafeArea()
            ScrollView {
                LazyVGrid(columns: gridItem) {
                    content
                }
            }.padding(.horizontal, 8)
        }
    }
}

struct TabBarView<T: View>: View {
    
    var titleContent: T

    @Binding var isPresented: Bool
    
    @Binding var selectedSongId: Dictionary<String, SongSource>
    
    @Binding var searchText: String
    
    var handleDoneBtn: (() -> ())?
    
    init(isPresented: Binding<Bool>, selectedSongId: Binding<Dictionary<String, SongSource>>, searchText: Binding<String>, handleDoneBtn: (() -> ())? = nil, @ViewBuilder titleContent: () -> T) {
        self._isPresented = isPresented
        self._selectedSongId = selectedSongId
        self._searchText = searchText
        self.handleDoneBtn = handleDoneBtn
        self.titleContent = titleContent()
    }
    
    var body: some View {
        ZStack {
            Color.BgColor.ignoresSafeArea()
            
            VStack(spacing: 4) {
                Spacer(minLength: 8)
                ZStack {
                    titleContent
                    HStack {
                        Button {
                            isPresented = false
                        } label: {
                            Image(systemName: "xmark.square").padding(8).font(.largeTitle).foregroundColor(.AccentColor)
                        }
                        Spacer()

                        Button {
                            if let handleDoneBtn = handleDoneBtn {
                                handleDoneBtn()
                            }
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8).foregroundColor(.NeutralColor)
                                Text(selectedSongId.count > 0 ? ("Add \(selectedSongId.count) song\(selectedSongId.count == 1 ? "": "s")") : "Choose for Me!").foregroundColor(.AccentColor)
                            }.frame(width: 128, height: 36).shadow(radius: 2)
                        }.padding(8)
                    }
                }
                SearchBarView(searchText: $searchText).padding([.horizontal], 8).padding(.bottom, 20)
            }
        }
    }
}

//struct LibraryView_Previews: PreviewProvider {
//    static var previews: some View {
//        TabBarView(isPresented: .constant(true), selectedSongId: .constant(["132": .Library]))
//    }
//}
