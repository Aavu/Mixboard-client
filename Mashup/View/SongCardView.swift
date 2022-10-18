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
    
    @ObservedObject var imageVM: ImageViewModel
    @StateObject var songCardVM = SongCardViewModel()
    
    init(spotifySong: Spotify.Track) {
        self.spotifySong = spotifySong
        self.imageVM = ImageViewModel(imageUrl: spotifySong.album.images[0].url)
    }
    
    init(song: Song?) {
        self.song = song
        self.imageVM = ImageViewModel(imageUrl: song?.img_url)
    }
    
    var body: some View {
        let title = song?.name ?? spotifySong?.name ?? "Song"
        let album = song?.album ?? spotifySong?.album.name ?? "Album"
        ZStack {
            Rectangle().foregroundColor(imageVM.averageColor).shadow(radius: 4)
            ZStack(alignment: .bottom) {
                HStack {
                    VStack(alignment: .leading) {    // Title and subtitle
                        StrokeText(text: title, width: 0.25, color: .black).font(.title2)
                        StrokeText(text: album, width: 0.25, color: .black).font(.body)
                    }
                    
                    Spacer()
                    
                    ImageView(image: $imageVM.image)
                    
                }.padding([.all], 8)

                if songCardVM.downloadProgress < 100 {
                    ProgressView(value: CGFloat(songCardVM.downloadProgress), total: CGFloat(SongCardViewModel.TOTAL_PROGRESS))
                        .scaleEffect(x: 1, y: 2, anchor: .bottom)
                }
            }
        }
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
        SongCardView(song: nil).frame(width: 300, height: 150)
    }
}
