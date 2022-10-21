//
//  TracksView.swift
//  Mashup
//
//  Created by Raghavasimhan Sankaranarayanan on 10/13/22.
//

import SwiftUI

struct TracksView: View {
    
    @EnvironmentObject var mashup: MashupViewModel
    @EnvironmentObject var library: LibraryViewModel
    
    let labelWidth: CGFloat = 86
    
    @Binding var audioProgress: CGFloat
    @Binding var playHeadProgress: CGFloat
    
    @State var isControllingPlayHead = false
    
    let lanes = ["Vocals", "Other", "Bass", "Drums"]
    
    var body: some View {
        ZStack(alignment: .leading) {
            VStack(spacing: 0.0) {
                HStack(spacing: 0.0) {
                    Rectangle().foregroundColor(.clear).frame(width: labelWidth, height: 20)
                    
                    BarAxisView(width: 1, height: 22)
                }
                
                ForEach(Lane.allCases, id: \.self) { lane in
                    LaneView(lane: lane, label: lanes[Int(lane.rawValue)!]) {
                        if let lanes = mashup.layoutInfo.lane[lane.rawValue] {
                            ForEach(lanes.layout) { region in
                                RegionView(lane: lane, uuid: region.id, song: library.getSong(songId: region.item.id))
                            }
                        }
                    }.cornerRadius(2)
                }
            }
            
            GeometryReader() { geo in
                let totalWidth = geo.frame(in: .local).width - labelWidth
                let playHeadMultiplier: CGFloat = totalWidth * CGFloat(mashup.lastBeat) / CGFloat(MashupViewModel.TOTAL_BEATS)
                PlayHeadView()
                    .offset(x: labelWidth - 10)
                    .offset(x: (isControllingPlayHead ? playHeadProgress : audioProgress) * playHeadMultiplier)
                    .gesture(DragGesture(coordinateSpace: .local)
                        .onChanged({ value in
                            isControllingPlayHead = true
                            
                            playHeadProgress =  min(max(0, value.location.x - labelWidth), totalWidth) / playHeadMultiplier
                        })
                            .onEnded({ value in
                                isControllingPlayHead = false
                                
                                playHeadProgress =  min(max(0, value.location.x - labelWidth), totalWidth) / playHeadMultiplier
                                audioProgress = playHeadProgress
                            })
                    )
            }
        }
    }
}

struct LaneView<T: View>: View {
    
    let lane: Lane
    let label: String
    
    @EnvironmentObject var library: LibraryViewModel
    @EnvironmentObject var mashup: MashupViewModel
    
    @State var position: CGFloat = -1
    
    var content: T
    
    init(lane: Lane, label: String, @ViewBuilder content: () -> T) {
        self.lane = lane
        self.label = label
        self.content = content()
    }
    
    var body: some View {
        HStack(spacing: 0.0) {
            
            ZStack(alignment: .trailing) {
                Rectangle()
                    .frame(width: 86)
                    .foregroundColor(.NeutralColor)
                    .padding([.bottom, .top], 1)
                
                Text(label).font(.subheadline).fontWeight(.bold).foregroundColor(.BgColor).padding(.all, 16)
            }
            
            ZStack {
                GeometryReader { geo in
                    Rectangle()
                        .foregroundColor(.SecondaryBgColor).opacity(0.75)
                        .onDrop(of: [.url], delegate: DropViewDelegate(position: $position, didDrop: { id, posX in
                            let c = geo.size.width / 32
                            let x = min(32 - 2, max(0, Int(round(posX / c)) - 2))
                            mashup.addRegion(region: Region(x: x, w: 4, item: Region.Item(id: id)), lane: lane)
                        }))
                        .padding([.bottom, .top], 1)
                    
                    content
                }
            }
        }
    }
}

struct RegionView: View {
    
    enum DragType {
        case None
        case start
        case end
        case move
    }
    
    @EnvironmentObject var mashup: MashupViewModel
    
    let song: Song?
    
    @State var conversion: CGFloat = 1

    @State var width: CGFloat = 0
    @State var position: CGFloat = 0
    
    @State var lastPosition: CGFloat = 0
    @State var lastWidth: CGFloat = 0
    
    let maxWidthinBeats:CGFloat = 32
    let pad:CGFloat = 4
    
    @State var dragType: DragType = .None
    
    private let lane: Lane
    private let uuid: UUID
    
    init(lane:Lane, uuid: UUID, song: Song?) {
        self.lane = lane
        self.uuid = uuid
        self.song = song
    }
    
    
    var body: some View {
        GeometryReader { geometry in
            SongCardView(song: song).frame(width: max(0, width - pad)).background(.black)
                .contextMenu(menuItems: {
                    Button {
                        mashup.removeRegion(lane: lane, id: uuid)
                    } label: {
                        Text("Remove")
                    }
                    
                })
                .offset(x: position).padding([.top, .bottom], 2*pad).padding([.leading, .trailing], pad)
                .simultaneousGesture(DragGesture()
                    .onChanged({ gesture in
                        switch dragType {
                        case .move:
                            if (position + width < geometry.frame(in: .local).width) {
                                position = max(0, lastPosition + gesture.translation.width)
                            }
                        case .end:
                            width = min(max(conversion, lastWidth + gesture.translation.width), geometry.frame(in: .local).width)
                        case .start:
                            position = max(0, lastPosition + gesture.translation.width)
                            if position > 0 {
                                width = min(max(conversion, lastWidth - gesture.translation.width), geometry.frame(in: .local).width)
                            }
                        default:
                            if gesture.location.x > (position + width - 24) {
                                width = min(max(conversion, lastWidth + gesture.translation.width), geometry.frame(in: .local).width)
                                dragType = .end
                            } else if gesture.location.x < (position + 24) {
                                position = max(0, lastPosition + gesture.translation.width)
                                if position > 0 {
                                    width = min(max(conversion, lastWidth - gesture.translation.width), geometry.frame(in: .local).width)
                                }
                                dragType = .start
                            } else {
                                position = max(0, lastPosition + gesture.translation.width)
                                dragType = .move
                            }
                        }
                    })
                                     
                         
                         
                    .onEnded({ gesture in
                        snapToGrid()
                        lastPosition = position
                        lastWidth = width
                        dragType = .None
                        let tempx = Int(position / conversion)
                        let totalLength = Int(width / conversion)
                        mashup.updateRegion(lane: lane, id: uuid, x: tempx, length: min(Int(maxWidthinBeats), totalLength))
                    })
                )
                .onAppear {
                    print("On Appear: \(geometry.size)")
                    updateFrame(geometry: geometry)
                }
                .onChange(of: geometry.size) { _ in
                    print("On Change: \(geometry.size)")
                    updateFrame(geometry: geometry)
                }
        }
    }
    
    func updateFrame(geometry: GeometryProxy) {
        conversion = geometry.frame(in: .local).width / CGFloat(MashupViewModel.TOTAL_BEATS)
        width = CGFloat(mashup.getRegion(lane: lane, id: uuid)!.w) * conversion
        position = CGFloat(mashup.getRegion(lane: lane, id: uuid)!.x) * conversion
        
        print(width, mashup.getRegion(lane: lane, id: uuid)!.w, conversion)
        lastPosition = position
        lastWidth = width
    }
    
    func snapToGrid() {
        position = round(position / conversion) * conversion
        width = round(width / conversion) * conversion
    }
}

//struct TracksView_Previews: PreviewProvider {
//    static var previews: some View {
//        TracksView(playHeadPosition: .constant(0))
//    }
//}
