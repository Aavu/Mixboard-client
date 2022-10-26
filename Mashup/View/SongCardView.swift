//
//  SongCardView.swift
//  Mashup
//
//  Created by Raghavasimhan Sankaranarayanan on 10/13/22.
//

import SwiftUI

struct SongCardView: View {
    var spotifySong: Spotify.Track?
    var song: Song?
    
    let minFrameWidthForText: CGFloat = 120
    
    @ObservedObject var imageVM: ImageViewModel
    
    init(spotifySong: Spotify.Track?) {
        self.spotifySong = spotifySong
        self.imageVM = ImageViewModel(imageUrl: spotifySong?.album.images[0].url)
    }
    
    init(song: Song?) {
        self.song = song
        self.imageVM = ImageViewModel(imageUrl: song?.img_url)
    }
    
    var body: some View {
        let title = song?.name ?? spotifySong?.name ?? "Song"
        let album = song?.album ?? spotifySong?.album.name ?? "Album"
        let padding: CGFloat = 8
        ZStack(alignment: .top) {
            Rectangle()
                .fill(imageVM.averageColor)
                .shadow(radius: 4)
            ZStack {
                GeometryReader { geo in
                    HStack {
                        if geo.frame(in: .local).width > minFrameWidthForText {
                            VStack(alignment: .leading) {    // Title and subtitle
                                StrokeText(text: title, width: 0.25, color: .black).font(.title3)
                                StrokeText(text: album, width: 0.25, color: .black).font(.body)
                            }
                            
                            Spacer()
                        }
                        ImageView(image: $imageVM.image)
                            .frame(height: max(0, geo.frame(in: .local).height - (padding * 2)))
                    }.padding([.all], padding)
                }
            }
        }
    }
}

struct UserLibSongCardView: View {
    var song: Song?
    
    @ObservedObject var imageVM: ImageViewModel
    
    @EnvironmentObject var userLibVM: UserLibraryViewModel
    @EnvironmentObject var mashupVM: MashupViewModel
    
    private let canShowOverlay: Bool
    
    init(song: Song?, canShowOverlay: Bool = true) {
        self.song = song
        self.imageVM = ImageViewModel(imageUrl: song?.img_url)
        self.canShowOverlay = canShowOverlay
    }
    
    var body: some View {
        let title = song?.name ?? "Song"
        let album = song?.album ?? "Album"
        let songId = song?.id ?? ""
        
        ZStack(alignment: .topLeading) {
            Rectangle().foregroundColor(imageVM.averageColor).shadow(radius: 4)
            ZStack(alignment: .bottom) {
                HStack {
                    VStack(alignment: .leading) {    // Title and subtitle
                        StrokeText(text: title, width: 0.25, color: .black).font(.subheadline)
                        StrokeText(text: album, width: 0.25, color: .black).font(.caption)
                    }
                    
                    Spacer()
                    
                    ImageView(image: $imageVM.image)
                    
                }.padding([.all], 8)
                
                
                if let progress = userLibVM.downloadProgress[songId] {
                    if progress < UserLibraryViewModel.TOTAL_PROGRESS {
                        ProgressView(value: CGFloat(progress), total: CGFloat(UserLibraryViewModel.TOTAL_PROGRESS))
                    }
                }
            }
            
            if userLibVM.isSelected[songId] ?? false {
                Button {
                    withAnimation {
                        if let songId = song?.id {
                            userLibVM.removeSong(songId: songId) { err in
                                userLibVM.dragOffset[songId] = nil
                                guard err != nil else { return }
                                mashupVM.deleteRegionsFor(songId: songId)
                            }
                        }
                    }
                } label: {
                    ZStack {
                        Color.BgColor.shadow(radius: 4).cornerRadius(4)
                        Text("Remove").foregroundColor(.AccentColor)
                    }
                }
                .frame(height: 32)
            }
        }
        .blur(radius: (userLibVM.silenceOverlayText[songId] != nil) && canShowOverlay ? 4 : 0)
        .overlay(content: {
            if canShowOverlay {
                if let txt = userLibVM.silenceOverlayText[songId] {
                    ZStack {
                        Color.red.opacity(0.5)
                        Text(txt)
                    }
                }
            }
        })
        .frame(maxHeight: 150)
        .simultaneousGesture(TapGesture()
            .onEnded({
                withAnimation {
                    if userLibVM.isSelected[songId] == nil {
                        userLibVM.isSelected[songId] = true
                    } else {
                        userLibVM.isSelected[songId] = !userLibVM.isSelected[songId]!
                    }
                    
                }
            })
        )
    }
}


// Reference: https://stackoverflow.com/questions/57334125/how-to-make-text-stroke-in-swiftui
struct StrokeText: View {
    let text: String
    let width: CGFloat
    let color: Color
    
    var body: some View {
        ZStack{
            ZStack{
                Text(text).offset(x:  width, y:  width)
                Text(text).offset(x: -width, y: -width)
                Text(text).offset(x: -width, y:  width)
                Text(text).offset(x:  width, y: -width)
            }
            .foregroundColor(color)
            Text(text)
        }.foregroundColor(.white)
    }
}

// artwork: URL(string:"https://i.scdn.co/image/ab67616d0000b2730c13d3d5a503c84fcc60ae94")!

struct SongCardView_Previews: PreviewProvider {
    static var previews: some View {
        UserLibSongCardView(song: nil).frame(width: 300, height: 300)
    }
}
