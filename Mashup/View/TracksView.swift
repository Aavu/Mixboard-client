//
//  TrackView.swift
//  Mashup
//
//  Created by Raghavasimhan Sankaranarayanan on 10/13/22.
//

import SwiftUI

struct TracksView: View {
    
    @ObservedObject var vocalLaneVM: LaneViewModel
    @ObservedObject var otherLaneVM: LaneViewModel
    @ObservedObject var bassLaneVM: LaneViewModel
    @ObservedObject var drumLaneVM: LaneViewModel
    
    @EnvironmentObject var mashup: MashupViewModel
    
    let labelWidth: CGFloat = 86
    
    @Binding var audioProgress: CGFloat
    @Binding var playHeadProgress: CGFloat
    
    @State var isControllingPlayHead = false
    
    var body: some View {
        ZStack(alignment: .leading) {
            VStack(spacing: 0.0) {
                HStack(spacing: 0.0) {
                    Rectangle().foregroundColor(.clear).frame(width: labelWidth, height: 20)
                    BarAxisView(width: 1, height: 22)
                }
                
                LaneView(lane: .Vocals).cornerRadius(2).environmentObject(vocalLaneVM)
                LaneView(lane: .Other).cornerRadius(2).environmentObject(otherLaneVM)
                LaneView(lane: .Bass).cornerRadius(2).environmentObject(bassLaneVM)
                LaneView(lane: .Drums).cornerRadius(2).environmentObject(drumLaneVM)
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

struct LaneView: View {
    
    let lane: Lane
    
    @EnvironmentObject var library: LibraryViewModel
    @EnvironmentObject var userLib: UserLibraryViewModel
    @EnvironmentObject var mashup: MashupViewModel
    @EnvironmentObject var laneVM: LaneViewModel
    
    @State var position: CGFloat = -1

    
    var body: some View {
        HStack(spacing: 0.0) {
            
            ZStack(alignment: .trailing) {
                Rectangle()
                    .frame(width: 86)
                    .foregroundColor(.NeutralColor)
                    .padding([.bottom, .top], 1)
                
                Text(lane.rawValue).font(.subheadline).fontWeight(.bold).foregroundColor(.BgColor).padding(.all, 16)
            }
            
            ZStack {
                GeometryReader { geo in
                    Rectangle()
                        .foregroundColor(.SecondaryBgColor).opacity(0.75)
                        .onDrop(of: [.url], delegate: DropViewDelegate(position: $position, didDrop: { id, posX in
                            let c = geo.size.width / 32
                            let x = min(32 - 2, max(0, Int(round(posX / c)) - 2))
                            let _ = laneVM.addRegion(region: Region(x: x, w: 4, item: Region.Item(id: id)))
                            mashup.updateRegions(lane: lane, regions: Array(laneVM.regions.values))
                        }))
                        .padding([.bottom, .top], 1)
                    
                    ForEach(Array(laneVM.regions.keys), id: \.self) { key in
                        if let region = laneVM.regions[key] {
                            RegionView(lane: lane, uuid: key, song: library.getSong(songId: region.item.id))
                        }
                    }
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
    @EnvironmentObject var laneVM: LaneViewModel
    
    let song: Song?
    
    @State var conversion: CGFloat = 1

    @State var width: CGFloat = 0
    @State var position: CGFloat = 0
    
    @State var lastPosition: CGFloat = 0
    @State var lastWidth: CGFloat = 0
    
    let maxWidthinBeats:CGFloat = 32
    let pad:CGFloat = 2
    
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
                        laneVM.removeRegion(id: uuid)
                        mashup.updateRegions(lane: lane, regions: Array(laneVM.regions.values))
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
                            width = min(max(0, lastWidth + gesture.translation.width), geometry.frame(in: .local).width)
                        case .start:
                            position = max(0, lastPosition + gesture.translation.width)
                            if position > 0 {
                                width = min(max(0, lastWidth - gesture.translation.width), geometry.frame(in: .local).width)
                            }
                        default:
                            if gesture.location.x > (position + width - 32) {
                                width = min(max(0, lastWidth + gesture.translation.width), geometry.frame(in: .local).width)
                                dragType = .end
                            } else if gesture.location.x < (position + 32) {
                                position = max(0, lastPosition + gesture.translation.width)
                                if position > 0 {
                                    width = min(max(0, lastWidth - gesture.translation.width), geometry.frame(in: .local).width)
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
                        laneVM.regions[uuid]!.x = tempx
                        let totalLength = Int(width / conversion)
                        laneVM.regions[uuid]!.w = min(Int(maxWidthinBeats), totalLength)
                        mashup.updateRegions(lane: lane, regions: Array(laneVM.regions.values))
                    })
                )
                .onAppear {
                    conversion = geometry.frame(in: .local).width / maxWidthinBeats
                    
                    width = CGFloat(laneVM.regions[uuid]!.w) * conversion
                    position = CGFloat(laneVM.regions[uuid]!.x) * conversion
                    lastWidth = width
                }
        }
        
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
