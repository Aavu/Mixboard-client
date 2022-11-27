//
//  MashupViewModel.swift
//  Mashup
//
//  Created by Raghavasimhan Sankaranarayanan on 10/16/22.
//

import Foundation
import Combine
import SwiftUI

class MashupViewModel: ObservableObject {
    @AppStorage("email") var currentEmail: String?
    
    @Published var loggedIn = false
        
    @Published var appFailed = false
    @Published var layoutInfo = Layout()
    
    @Published var isEmpty = true
    @Published var isSelected = Dictionary<UUID, Bool>()
    
    @Published var readyToPlay = false
    @Published var showGenerationProgress = true
    
    @Published var isFocuingSongs = false
    
    @Published var tracksViewLocation: CGPoint = .zero
    @Published var tracksViewSize: CGSize = .zero
    @Published var trackLabelWidth: CGFloat = 96
    
    @Published var userLibCardWidth: CGFloat = 0
    
    static let TOTAL_BEATS = 32
    
    @ObservedObject var audioManager = AudioManager.shared
    
    private var errorSubscriber: AnyCancellable?
    
    @Published var appError: AppError?
    @Published var showError = false
    
    @Published var userInfoViewVisibility: NavigationSplitViewVisibility = .detailOnly
    
    private var userInfoVM: UserInfoViewModel?
    private var userLibVM: UserLibraryViewModel?
    
    init() {
        for lane in Lane.allCases {
            layoutInfo.lane[lane.rawValue] = Layout.Track()
        }
        self.addSubscriber()
        LuckyMeManager.shared.loadTemplateFile()
        
        self.loggedIn = (FirebaseManager.getCurrentUser() != nil)
        if loggedIn {
            self.currentEmail = FirebaseManager.getCurrentUser()?.email
        }
        
        createNewSession()
    }
    
    func attach(userInfoVM: UserInfoViewModel, userLibVM: UserLibraryViewModel) {
        self.userInfoVM = userInfoVM
        self.userLibVM = userLibVM
    }
    
    func addSubscriber() {
        errorSubscriber = $appError.sink {[weak self] err in
            DispatchQueue.main.async {
                BackendManager.shared.isGenerating = false
                self?.showError = (err != nil)
            }
        }
    }
    
    func createNewSession() {
        if !loggedIn { return }
        
        guard let email = currentEmail else {
            print("Function: \(#function), line: \(#line),", "Please signin before creating session")
            return
        }
        
        let url = URL(string: Config.SERVER + HttpRequests.NEW_SESSION)!
        let body = try? JSONEncoder().encode(["email": email])
        
        NetworkManager.request(url: url, type: .POST, httpbody: body) { completion in
            switch completion {
            case .finished:
                break
            case .failure(let e):
                print("Function: \(#function), line: \(#line),", e)
                self.appError = AppError(description: "Server not responding. Please try again later...")
            }
        } completion: { (data:[String:Int]?) in
            print("Fetched Library")
        }
    }
    
    func clearCanvas() {
        for lane in Lane.allCases {
            if layoutInfo.lane[lane.rawValue] != nil {
                layoutInfo.lane[lane.rawValue]!.layout = [Region]()
            }
        }
        AudioManager.shared.reset()
        readyToPlay = false
        isEmpty = true
    }
    
    func updateRegions(lane: Lane, regions: [Region]) {
        layoutInfo.lane[lane.rawValue]?.layout = regions
        
        isEmpty = isCanvasEmpty()
    }
    
    func isCanvasEmpty() -> Bool {
        for lane in Lane.allCases {
            if let lanes = layoutInfo.lane[lane.rawValue] {
                if lanes.layout.count > 0 {
                    return false
                }
            }
        }
        
        return true
    }
    
    func getLastBeat() -> Int {
        var lastBeatTemp = 0
        for lane in Lane.allCases {
            if let lanes = layoutInfo.lane[lane.rawValue] {
                for region in lanes.layout {
                    lastBeatTemp = max(lastBeatTemp, region.x + region.w)
                }
            }
        }
        return min(MashupViewModel.TOTAL_BEATS, lastBeatTemp)
    }
    
    private func getRegionIds(with laneState: LaneState) -> [UUID] {
        var regions = [UUID]()
        for lane in Lane.allCases {
            if let lanes = layoutInfo.lane[lane.rawValue] {
                for region in lanes.layout {
                    if lanes.laneState == laneState {
                        regions.append(region.id)
                    }
                }
            }
        }
        
        return regions
    }
    
    func handleMute(lane: Lane) {
        if let l = layoutInfo.lane[lane.rawValue] {
            layoutInfo.lane[lane.rawValue]!.laneState = l.laneState == .Mute ? .Default : .Mute
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            let regionsToMute = getRegionIds(with: .Mute)
            
            // Respect solo regions. Only if there are no soloed regions, handle mute
            let soloRegions = getRegionIds(with: .Solo)
            if soloRegions.count > 0 {
                audioManager.handleSolo(regionIds: soloRegions)
            } else {
                audioManager.handleMute(regionIds: regionsToMute)
            }
        }
    }
    
    func handleSolo(lane: Lane) {
        if let l = layoutInfo.lane[lane.rawValue] {
            layoutInfo.lane[lane.rawValue]!.laneState = l.laneState == .Solo ? .Default : .Solo
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            let regionsToSolo = getRegionIds(with: .Solo)
            audioManager.handleSolo(regionIds: regionsToSolo)
        }
    }
    
    func addRegion(region: Region, lane: Lane) {
        layoutInfo.lane[lane.rawValue]?.layout.append(region)
        isEmpty = false
        setSelected(uuid: region.id, isSelected: false)
        readyToPlay = false
        
//        let uuid = UUID().uuidString
//        generateMashup(uuid: uuid, lastSessionId: userInfoVM?.getLastSessionId())
    }
    
    func setSelected(uuid: UUID, isSelected: Bool) {
        self.isSelected[uuid] = isSelected
    }
    
    func unselectAllRegions() {
        isSelected.keys.forEach{ isSelected[$0] = false }
    }
    
    func getRegion(lane: Lane, id: UUID) -> Region? {
        if let lanes = layoutInfo.lane[lane.rawValue] {
            for region in lanes.layout {
                if region.id == id {
                    return region
                }
            }
        }
        
        return nil
    }
    
    func removeRegion(lane: Lane, id: UUID) {
        if let lanes = layoutInfo.lane[lane.rawValue] {
            for (idx, region) in lanes.layout.enumerated() {
                if region.id == id {
                    layoutInfo.lane[lane.rawValue]!.layout.remove(at: idx)
                    isEmpty = isCanvasEmpty()
                    audioManager.currentMusic?.remove(id: region.id)
                    audioManager.scheduleMusic()
                    return
                }
            }
        }
    }
    
    func updateRegion(id: UUID, x: Int, length: Int) -> Bool {
        for lane in Lane.allCases {
            if let lanes = layoutInfo.lane[lane.rawValue] {
                for (idx, region) in lanes.layout.enumerated() {
                    if region.id == id {
                        let posChanged = region.x != x
                        let lengthChanged = region.w != length

                        
                        let prevPosition = self.layoutInfo.lane[lane.rawValue]!.layout[idx].x
                        self.layoutInfo.lane[lane.rawValue]!.layout[idx].x = x
                        self.layoutInfo.lane[lane.rawValue]!.layout[idx].w = length
                        
                        let prevState = self.layoutInfo.lane[lane.rawValue]!.layout[idx].state
                        if lengthChanged {
                            self.layoutInfo.lane[lane.rawValue]!.layout[idx].state = .New
                            readyToPlay = false
//                            let uuid = UUID().uuidString
//                            generateMashup(uuid: uuid, lastSessionId: userInfoVM?.getLastSessionId())
                        } else {
                            if posChanged {
                                self.layoutInfo.lane[lane.rawValue]!.layout[idx].state = (prevState == .New) ? .New : .Moved
                                if self.layoutInfo.lane[lane.rawValue]!.layout[idx].state != .New {
                                    if let music = self.audioManager.currentMusic {
                                        let _pos = self.layoutInfo.lane[lane.rawValue]!.layout[idx].x
                                        let err = music.update(for: region.id, position: _pos)
                                        if err != .Success {
                                            self.layoutInfo.lane[lane.rawValue]!.layout[idx].state = prevState
                                            self.layoutInfo.lane[lane.rawValue]!.layout[idx].x = prevPosition
                                            appError = AppError(description: "Cannot update position for this region")
                                            print(err)
                                            return false
                                        }
                                        
                                        audioManager.scheduleMusic()
                                    }
                                }
                            }
                        }
                        
                        return true
                    }
                }
            }
        }
        
        return false
    }
    
    func setRegionState(region: inout Region, state: Region.State) {
        region.state = state
    }
    
    /// Updates region state of all regions in layout. This is useful to call after each generation so as to track user edits
    func updateRegionState(_ state: Region.State = .Ready) {
        for lane in Lane.allCases {
            if let lanes = self.layoutInfo.lane[lane.rawValue] {
                for (idx, _) in lanes.layout.enumerated() {
                    self.layoutInfo.lane[lane.rawValue]!.layout[idx].state = state
                }
            }
        }
    }
    
    func changeLane(regionId: UUID, currentLane: Lane, newLane: Lane) {
        if let lanes = layoutInfo.lane[currentLane.rawValue] {
            for (idx, region) in lanes.layout.enumerated() {
                if region.id == regionId {
                    // If the region state is ready, it means it has generation. Change it to new to denote it is a new region and requires generation
                    if region.state == .Ready {
                        layoutInfo.lane[currentLane.rawValue]!.layout[idx].state = .New
                    }
                    layoutInfo.lane[currentLane.rawValue]!.layout.remove(at: idx)
                    layoutInfo.lane[newLane.rawValue]?.layout.append(region)
                    isEmpty = false
                    setSelected(uuid: region.id, isSelected: false)
                    readyToPlay = false
                    
//                    let uuid = UUID().uuidString
//                    generateMashup(uuid: uuid, lastSessionId: userInfoVM?.getLastSessionId())
                    
                    return
                }
            }
        }
    }
    
    func deleteRegionsFor(songId: String) {
        var didRemove = false
        for lane in Lane.allCases {
            if let regions = layoutInfo.lane[lane.rawValue]?.layout {
                for region in regions {
                    if region.item.id == songId {
                        removeRegion(lane: lane, id: region.id)
                        readyToPlay = false
                        didRemove = true
                    }
                }
            }
        }
        
        if didRemove {
            updateRegionState(.New)
        }
    }
    
    func getLaneForLocation(location: CGPoint) -> Lane? {
        if location.x < tracksViewLocation.x  || location.x  > tracksViewLocation.x + tracksViewSize.width {
            return nil
        }
        
        if location.y < tracksViewLocation.y || location.y > tracksViewLocation.y + tracksViewSize.height {
            return nil
        }
        
        let laneHeight = tracksViewSize.height / 4
        
        if location.y < laneHeight + tracksViewLocation.y {
            return .Vocals
        } else if location.y < 2*laneHeight + tracksViewLocation.y {
            return .Other
        } else if location.y < 3*laneHeight + tracksViewLocation.y {
            return .Bass
        }
        
        return .Drums
    }
    
    func handleDropRegion(songId: String, dropLocation: CGPoint) -> Bool {
        if let lane = getLaneForLocation(location: dropLocation) {
            let conversion = (tracksViewSize.width - trackLabelWidth) / CGFloat(MashupViewModel.TOTAL_BEATS)
            let x = min(max(0, Int(round((dropLocation.x - tracksViewLocation.x) / conversion) - 4)), MashupViewModel.TOTAL_BEATS - 8)
            addRegion(region: Region(x: Int(x), w: 8, item: Region.Item(id: songId), state: .New), lane: lane)
        }
        
        return true
    }
    
    func restoreFromHistory(history: History) {
        let layout = history.layout
        for lane in Lane.allCases {
            if let lanes = layout.lane[lane.rawValue] {
                updateRegions(lane: lane, regions: lanes.layout)
            }
        }
        
        audioManager.reset()
        
        let uuid = history.id ?? UUID().uuidString
        
        generateMashup(uuid: uuid, lastSessionId: nil, addToHistory: false)
    }
    
    
    func getNumRegions() -> Int {
        var count = 0
        for lane in Lane.allCases {
            if let lanes = layoutInfo.lane[lane.rawValue] {
                count += lanes.layout.count
            }
        }
        return count
    }
    
    func surpriseMe(songs: [Song]) {
        if let layout = LuckyMeManager.shared.surpriseMe(songs: songs) {
            self.layoutInfo = layout
            isEmpty = isCanvasEmpty()
            readyToPlay = false
            userInfoVM?.lastSessionId = nil
        } else {
            self.appError = AppError(description: "Error creating luckyme template")
        }
    }
    
    func loadExampleData() -> Bool {
        guard let url = Bundle.main.url(forResource: "generateRequestExample", withExtension: "json")
        else {
            self.appError = AppError(description: "JSON file not found")
            return false
        }
        
        do {
            let data = try Data(contentsOf: url)
            self.layoutInfo = try JSONDecoder().decode(Layout.self, from: data)
        } catch let e {
            self.appError = AppError(description: e.localizedDescription)
            print("Function: \(#function), line: \(#line),", e)
            return false
        }
        
        return true
    }
    
    func getRegionIds(includeReady: Bool = true) -> [String] {
        var regionIds = [String]()
        for lane in Lane.allCases {
            if let lanes = self.layoutInfo.lane[lane.rawValue] {
                for region in lanes.layout {
                    if region.state == .New || includeReady {
                        regionIds.append(region.id.uuidString)
                    }
                }
            }
        }
        
        return regionIds
    }
    
    func removeRegionsFromMusic(with state: Region.State) {
        guard let music = audioManager.currentMusic else {
            audioManager.set(music: MBMusic())
            return
        }
        
        let tempMusic = MBMusic()
        
        for lane in Lane.allCases {
            if let lanes = self.layoutInfo.lane[lane.rawValue] {
                for region in lanes.layout {
                    if region.state != state {
                        if let audio = music.audios[region.id.uuidString] {
                            tempMusic.add(audio: audio)
                        }
                    }
                }
            }
        }
        audioManager.set(music: tempMusic)
    }
    
    
    func generateMashup(uuid: String, lastSessionId: String?, addToHistory: Bool = true, completion: (() -> ())? = nil) {
        showGenerationProgress = lastSessionId == nil
        readyToPlay = false
        
        if lastSessionId == nil {
            audioManager.currentMusic = MBMusic()
            updateRegionState(.New)
        } else {
            removeRegionsFromMusic(with: .New)
        }
        
        let regionIds = self.getRegionIds(includeReady: false)

        guard regionIds.count > 0 else {
            if let completion = completion {
                completion()
            }
            return
        }
        
        BackendManager.shared.sendGenerateRequest(uuid: uuid, lastSessionId: lastSessionId, layout: self.layoutInfo, regionIds: regionIds, statusCallback: { audio in
            if let audio = audio {
                DispatchQueue.main.async {
                    self.audioManager.tempo = audio.tempo
                }
                self.audioManager.currentMusic?.add(audio: audio)
            } else {
                DispatchQueue.main.async {
                    self.appError = AppError(description: "Audio is nil")
                }
            }
            
        }) {layout, err in
            if let err = err {
                DispatchQueue.main.async {
                    self.appError = AppError(description: err.localizedDescription)
                }
                print("Function: \(#function), line: \(#line),", err)
            }
            
            if let layout = layout {
                DispatchQueue.main.async {
                    self.layoutInfo = layout
                    self.updateRegionState(.Ready)
                }
            } else {
                print("Function: \(#function), line: \(#line),", "Warning: Layout is nil")
            }
            
            DispatchQueue.main.async {
                self.readyToPlay = true
            }
            
            if addToHistory {
                if let userLibVM = self.userLibVM, let userInfoVM = self.userInfoVM {
                    let history = History(id: uuid, audio: nil, date: Date(), userLibrary: userLibVM.songs, layout: self.layoutInfo)
                    DispatchQueue.main.async {
                        userInfoVM.current = history
                    }
                    

                    print("adding to history")
                    userInfoVM.add(history: history)
                }
            }
            
            if let completion = completion {
                completion()
            }
        }
    }
}
