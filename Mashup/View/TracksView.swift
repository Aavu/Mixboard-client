//
//  TracksView.swift
//  Mashup
//
//  Created by Raghavasimhan Sankaranarayanan on 10/13/22.
//

import SwiftUI

enum DragType {
    case None
    case start
    case end
    case horizontal
    case vertical
}

struct TracksView: View {
    
    @EnvironmentObject var mashup: MashupViewModel
    @EnvironmentObject var library: LibraryViewModel
    @EnvironmentObject var spotify: SpotifyViewModel
    
    let labelWidth: CGFloat = 86
    
    @Binding var audioProgress: CGFloat
    @Binding var playHeadProgress: CGFloat
    
    @State var isControllingPlayHead = false
    
    let lanes = ["Vocals", "Other", "Bass", "Drums"]

    @State var startX = Dictionary<UUID, CGFloat>()
    @State var endX = Dictionary<UUID, CGFloat>()
    @State var yPos = Dictionary<UUID, CGFloat>()
    
    @State var dragType: DragType = .None
    @State var dummyRegionView: RegionView?
    
    
    var body: some View {
            ZStack(alignment: .leading) {
                VStack(spacing: 0.0) {
                    HStack(spacing: 0.0) {
                        Rectangle().foregroundColor(.clear).frame(width: labelWidth, height: 20)
                        
                        BarAxisView(width: 1, height: 22)
                    }
                    
                    GeometryReader { geo in
                        ZStack(alignment: .topLeading) {
                            if let dummyRegionView = dummyRegionView {
                                let laneMultiplier = CGFloat(Lane.allCases.firstIndex(of: dummyRegionView.lane)!)
                                dummyRegionView
                                    .frame(width: geo.size.width - 86, height: geo.size.height / 4)
                                    .offset(x: 86, y: (laneMultiplier * geo.size.height / 4) + (yPos[dummyRegionView.uuid] ?? 0))
                                    .zIndex(10)
                                    .transition(AnyTransition.identity)
                            }
                            VStack(spacing: 0.0) {
                                ForEach(Lane.allCases, id: \.self) { lane in
                                    ZStack {
                                        LaneView(lane: lane, label: lanes[Int(lane.rawValue)!]).cornerRadius(2)
                                        
                                        if let lanes = mashup.layoutInfo.lane[lane.rawValue] {
                                            ForEach(lanes.layout) { region in
                                                GeometryReader { regionGeo in
                                                    let song = library.getSong(songId: region.item.id) ?? spotify.getSong(songId: region.item.id)
                                                    RegionView(lane: lane, uuid: region.id, song: song, dragType: $dragType, startX: $startX, endX: $endX)
                                                        .frame(width: geo.size.width - 86)
                                                        .offset(x: 86, y: yPos[region.id] ?? 0)
                                                        .onAppear {
                                                            yPos[region.id] = 0
                                                        }
                                                        .simultaneousGesture(DragGesture(coordinateSpace: .global)
                                                            .onChanged({ value in
                                                                if dragType == .None || dragType == .horizontal || dragType == .vertical {
                                                                    if value.translation.height > 0 {
                                                                        dummyRegionView = RegionView(lane: lane, uuid: region.id, song: song, dragType: $dragType, startX: $startX, endX: $endX)
                                                                    }
                                                                    
                                                                    dragType = .vertical
                                                                    
                                                                    yPos[region.id] = value.translation.height
                                                                    withAnimation {
                                                                        
                                                                    }
                                                                    
                                                                }
                                                            })
                                                                             
                                                            .onEnded({ value in
                                                                dummyRegionView = nil
                                                                if let l = mashup.getLaneForLocation(location: value.location) {
                                                                    if l != lane {
                                                                        print(region.x ,region.w)
                                                                        mashup.changeLane(regionId: region.id, currentLane: lane, newLane: l)
                                                                        print(region.x ,region.w)
                                                                    }
                                                                }
                                                                yPos[region.id] = 0
                                                                dragType = .None
                                                            })
                                                        )
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .onAppear {
                            mashup.tracksViewLocation = CGPoint(x: geo.frame(in: .global).minX + 86, y: geo.frame(in: .global).minY)
                            mashup.tracksViewSize = geo.frame(in: .global).size
                        }
                        
                        .onChange(of: geo.size) { newValue in
                            mashup.tracksViewLocation = CGPoint(x: geo.frame(in: .global).minX + 86, y: geo.frame(in: .global).minY)
                            mashup.tracksViewSize = geo.frame(in: .global).size
                        }
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
            .onTapGesture {
                mashup.unselectAllRegions()
            }
    }
}

struct LaneView: View {
    
    let lane: Lane
    let label: String
    
    @EnvironmentObject var library: LibraryViewModel
    @EnvironmentObject var mashup: MashupViewModel
    
    init(lane: Lane, label: String) {
        self.lane = lane
        self.label = label
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
                Rectangle()
                    .foregroundColor(.SecondaryBgColor).opacity(0.75)
                    .padding([.bottom, .top], 1)
            }
        }
    }
}

struct RegionView: View {
    
    @EnvironmentObject var mashup: MashupViewModel
    
    let song: Song?
    
    @State var conversion: CGFloat = 1

    @Binding var endX: [UUID: CGFloat]
    @Binding var startX: [UUID: CGFloat]
    
    @State var lastStartX: CGFloat = 0
    @State var lastEndX: CGFloat = 0
    @State var scale: CGFloat = 1
    
    let maxWidthinBeats:CGFloat = 32
    let pad:CGFloat = 1
    
    @Binding var dragType: DragType
    
    let lane: Lane
    let uuid: UUID
    
    init(lane:Lane, uuid: UUID, song: Song?, dragType: Binding<DragType>, startX: Binding<[UUID: CGFloat]>, endX: Binding<[UUID: CGFloat]>) {
        self.lane = lane
        self.uuid = uuid
        self.song = song
        self._dragType = dragType
        self._startX = startX
        self._endX = endX
    }
    
    
    var body: some View {
        let start = startX[uuid] ?? 0
        let end = endX[uuid] ?? 0
        ZStack {
            let isSelected = mashup.isSelected[uuid] ?? false
            let width = end - start
            GeometryReader { geometry in
                SongCardView(song: song).frame(width: max(0, width - 2*pad)).background(.black)
                    .onTapGesture {
                        withAnimation {
                            mashup.unselectAllRegions()
                            if !isSelected {
                                mashup.setSelected(uuid: uuid, isSelected: true)
                            }
                        }
                    }
                    .border(Color.NeutralColor, width: isSelected ? 4 : 0)
                    .animation(.spring(), value: isSelected)
                    .offset(x: start)
                    .gesture(DragGesture(minimumDistance: 5)
                        .onChanged({ value in
                            
                            dragType = .horizontal
                            let tempStartX = lastStartX + value.translation.width
                            let tempEndX = lastEndX + value.translation.width
                            if tempStartX >= 0 && tempEndX < geometry.size.width {
                                startX[uuid] = tempStartX
                                endX[uuid] = tempEndX
                                withAnimation {
                                    
                                }
                            }
                            
                        })
                             
                        .onEnded({ value in
                            startX[uuid] = round(start / conversion) * conversion
                            endX[uuid] = round(end / conversion) * conversion
                            withAnimation {
                                
                            }
                            handleDragEnded(geometry: geometry)
                        })
                    )
                    .onAppear {
                        updateFrame(geometry: geometry)
                    }
                    .onChange(of: geometry.size) { _ in
                        updateFrame(geometry: geometry)
                    }
                
                
                ZStack {
                    let handleWidth:CGFloat = 32
                    Rectangle()
//                        .fill(Color.black)
                        .fill(LinearGradient(colors: [.black.opacity(0.2), .clear], startPoint: .leading, endPoint: .trailing))
                        .opacity(0.25)
                        .frame(width: handleWidth)
                        .offset(x: start)
                        .simultaneousGesture(DragGesture(minimumDistance: 5)
                            .onChanged({ value in
                                dragType = .start
                                let temp = max(0, lastStartX + value.translation.width)
                                if (endX[uuid]! - temp) >= conversion {
                                    startX[uuid] = temp
                                }
                                withAnimation {
                                    
                                }
                            })
                                .onEnded({ value in
                                    startX[uuid] = round(start / conversion) * conversion
                                    withAnimation {
                                        
                                    }
                                    handleDragEnded(geometry: geometry)
                                })
                        )
                    Rectangle()
//                        .fill(Color.black)
                        .fill(LinearGradient(colors: [.clear, .black.opacity(0.2)], startPoint: .leading, endPoint: .trailing))
                        .opacity(0.25)
                        .frame(width: handleWidth)
                        .offset(x: end - handleWidth - 2*pad)
                        .simultaneousGesture(DragGesture(minimumDistance: 5)
                            .onChanged({ value in
                                dragType = .end
                                let temp = min(geometry.size.width, lastEndX + value.translation.width)
                                if (temp - startX[uuid]!) >= conversion {
                                    endX[uuid] = temp
                                }
                                withAnimation {
                                    
                                }
                            })
                                .onEnded({ value in
                                    endX[uuid] = round(end / conversion) * conversion
                                    withAnimation {
                                        
                                    }
                                    handleDragEnded(geometry: geometry)
                                })
                        )
                }
                
                if isSelected {
                    Button {
                        withAnimation {
                            mashup.removeRegion(lane: lane, id: uuid)
                        }
                    } label: {
                        ZStack {
                            Color.BgColor.shadow(radius: 4).cornerRadius(4)
                            Text("Remove").foregroundColor(.AccentColor)
                        }
                    }
                    .frame(width: width - pad, height: 32)
                    .offset(x: start)
                }
            }

        }
        .padding([.top, .bottom], 2*pad).padding([.leading, .trailing], pad)
    }
    
    func updateFrame(geometry: GeometryProxy) {
        conversion = geometry.frame(in: .local).width / CGFloat(MashupViewModel.TOTAL_BEATS)
        let width = CGFloat(mashup.getRegion(lane: lane, id: uuid)!.w) * conversion
        startX[uuid] = CGFloat(mashup.getRegion(lane: lane, id: uuid)!.x) * conversion
        endX[uuid] = startX[uuid]! + width
        
        lastStartX = startX[uuid]!
        lastEndX = endX[uuid]!
    }
    
    func handleDragEnded(geometry: GeometryProxy) {
        dragType = .None
        let tempx = Int(round(startX[uuid]! / conversion))
        let length = Int(round((endX[uuid]! - startX[uuid]!) / conversion))
//        print(tempx, min(Int(MashupViewModel.TOTAL_BEATS) - tempx, length), endX[uuid]!, startX[uuid]!, conversion)
        mashup.updateRegion(id: uuid, x: tempx, length: min(Int(MashupViewModel.TOTAL_BEATS) - tempx, length))
        startX[uuid] = CGFloat(tempx) * conversion
        endX[uuid] = CGFloat(length + tempx) * conversion
        lastStartX = startX[uuid]!
        lastEndX = endX[uuid]!
    }
}

//struct TracksView_Previews: PreviewProvider {
//    static var previews: some View {
//        TracksView(playHeadPosition: .constant(0))
//    }
//}
