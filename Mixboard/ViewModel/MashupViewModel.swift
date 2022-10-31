//
//  MashupViewModel.swift
//  Mashup
//
//  Created by Raghavasimhan Sankaranarayanan on 10/16/22.
//

import Foundation
import Combine

class MashupViewModel: ObservableObject {
    @Published var canDisplayLibrary = false
    
    @Published var layoutInfo = Layout()
    @Published var isGenerating = false
    @Published var isEmpty = true
    @Published var isSelected = Dictionary<UUID, Bool>()
    
    @Published var readyToPlay = false
    
    @Published var isFocuingSongs = false
    
    @Published var tracksViewLocation: CGPoint = .zero
    @Published var tracksViewSize: CGSize = .zero
    
    @Published var userLibCardWidth: CGFloat = 0
    
    static let TOTAL_BEATS = 32
    
    @Published var lastBeat = TOTAL_BEATS
    @Published var generationProgress:TaskStatus.Status?
    
    var generationTaskId: String?
    var mashupAudio: Audio?
    var tempo: Float?
    
    var timer: AnyCancellable?
    
    private var errorSubscriber: AnyCancellable?
    
    @Published var appError: AppError?
    @Published var showError = false
    
    init() {
        for lane in Lane.allCases {
            layoutInfo.lane[lane.rawValue] = Layout.Track()
        }
        self.createLibrary()
        self.addSubscriber()
        LuckyMeManager.instance.loadTemplateFile()
    }
    
    func addSubscriber() {
        errorSubscriber = $appError.sink {[weak self] err in
            DispatchQueue.main.async {
                self?.isGenerating = false
                self?.showError = (err != nil)
            }
        }
    }
    
    func createLibrary() {
        guard let url = URL(string: Config.SERVER + HttpRequests.ROOT) else {
            self.appError = AppError(description: "Url invalid")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        URLSession.shared.dataTask(with: request) { data, response, err in
            guard let _ = data, err == nil else {
                DispatchQueue.main.async {
                    self.appError = AppError(description: err?.localizedDescription)
                }
                return
            }
            
            DispatchQueue.main.async {
                print("Library Created")
                self.canDisplayLibrary = true
            }
            
        }.resume()
    }
    
    func clearCanvas() {
        for lane in Lane.allCases {
            if layoutInfo.lane[lane.rawValue] != nil {
                layoutInfo.lane[lane.rawValue]!.layout = [Region]()
            }
        }
        isEmpty = true
    }
    
    func updateRegions(lane: Lane, regions: [Region]) {
        layoutInfo.lane[lane.rawValue]?.layout = regions
        
        isEmpty = isCanvasEmpty()
        
        updateLastBeat()
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
    
    func updateLastBeat() {
        var lastBeatTemp = 0
        for lane in Lane.allCases {
            if let lanes = layoutInfo.lane[lane.rawValue] {
                for region in lanes.layout {
                    lastBeatTemp = max(lastBeatTemp, region.x + region.w)
                }
            }
        }
        lastBeat = min(MashupViewModel.TOTAL_BEATS, lastBeatTemp)
    }
    
    func addRegion(region: Region, lane: Lane) {
        layoutInfo.lane[lane.rawValue]?.layout.append(region)
        isEmpty = false
        updateLastBeat()
        setSelected(uuid: region.id, isSelected: false)
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
                    updateLastBeat()
                    return
                }
            }
        }
    }
    
    func updateRegion(id: UUID, x: Int, length: Int) {
        for lane in Lane.allCases {
            if let lanes = layoutInfo.lane[lane.rawValue] {
                for (idx, region) in lanes.layout.enumerated() {
                    if region.id == id {
                        layoutInfo.lane[lane.rawValue]!.layout[idx].x = x
                        layoutInfo.lane[lane.rawValue]!.layout[idx].w = length
                        updateLastBeat()
                        return
                    }
                }
            }
        }
    }
    
    func changeLane(regionId: UUID, currentLane: Lane, newLane: Lane) {
        if let lanes = layoutInfo.lane[currentLane.rawValue] {
            for (idx, region) in lanes.layout.enumerated() {
                if region.id == regionId {
                    layoutInfo.lane[currentLane.rawValue]!.layout.remove(at: idx)
                    layoutInfo.lane[newLane.rawValue]?.layout.append(region)
                    updateLastBeat()
                    isEmpty = false
                    setSelected(uuid: region.id, isSelected: false)
                    return
                }
            }
        }
    }
    
    func deleteRegionsFor(songId: String) {
        for lane in Lane.allCases {
            if let regions = layoutInfo.lane[lane.rawValue]?.layout {
                for region in regions {
                    if region.item.id == songId {
                        removeRegion(lane: lane, id: region.id)
                    }
                }
            }
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
            let conversion = (tracksViewSize.width - 86) / CGFloat(MashupViewModel.TOTAL_BEATS)
            let x = min(max(0, Int(round((dropLocation.x - tracksViewLocation.x) / conversion) - 4)), MashupViewModel.TOTAL_BEATS - 8)
            addRegion(region: Region(x: Int(x), w: 8, item: Region.Item(id: songId)), lane: lane)
        }
        
        return true
    }
    
    func restoreFromHistory(history: History) {
        self.mashupAudio = history.audio

        let layout = history.layout
        for lane in Lane.allCases {
            if let lanes = layout.lane[lane.rawValue] {
                updateRegions(lane: lane, regions: lanes.layout)
            }
        }
    }
    
    func surpriseMe(songs: [Song]) {
        if let layout = LuckyMeManager.instance.surpriseMe(songs: songs) {
            self.layoutInfo = layout
            isEmpty = isCanvasEmpty()
            updateLastBeat()
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
            return false
        }
        
        return true
    }
    
    func sendGenerateRequest(uuid: UUID, onCompletion: ((Audio?, Layout) -> ())?) {
        guard let url = URL(string: Config.SERVER + HttpRequests.GENERATE) else {
            self.appError = AppError(description: "Url invalid")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Application/json", forHTTPHeaderField: "Content-Type")
        
        request.httpBody = try? JSONEncoder().encode(self.layoutInfo.lane)
        
//        if let body = request.httpBody {
//            let out = try? JSONSerialization.jsonObject(with: body)
//            print(out as Any)
//        }
        
        isGenerating = true
        
        URLSession.shared.dataTask(with: request) { data, response, err in
            guard let data = data, err == nil else {
                self.appError = AppError(description: err?.localizedDescription)
                self.isGenerating = false
                return
            }
            
            do {
                let resp = try JSONSerialization.jsonObject(with: data) as! Dictionary<String, String>
                DispatchQueue.main.async { [self] in
                    mashupAudio = nil
                    tempo = nil
                    generationTaskId = resp["task_id"]
                    
                    readyToPlay = false
                    
                    guard let taskId = self.generationTaskId else { return }
                    
                    self.generationProgress = TaskStatus.Status(progress: 5, description: "Hold On! Creating some magic...")
                    self.updateStatus(taskId: taskId)
                    
                    timer = Timer
                        .publish(every: 0.5, on: .current, in: .common)
                        .autoconnect()
                        .sink(receiveValue: { value in
                            if self.generationProgress?.progress == 100 && self.isGenerating {
                                self.fetchMashup(uuid: uuid) { url in
                                    if let audio = self.mashupAudio {
                                        self.timer = nil
                                        self.isGenerating = false
                                        
                                        guard let onCompletion = onCompletion else { return }
                                        onCompletion(audio, self.layoutInfo)
                                    }
                                }
                            }
                        })
                }
            } catch let e {
                self.appError = AppError(description: e.localizedDescription)
                self.isGenerating = false
            }
            
        }.resume()
    }
    
    func updateStatus(taskId: String, tryNum: Int = 0) {
        if self.generationProgress?.progress == 100 { return }
        
        guard let url = URL(string: Config.SERVER + HttpRequests.STATUS + "/" + taskId) else {
            self.appError = AppError(description: "Url invalid")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Application/json", forHTTPHeaderField: "Content-Type")
        
        URLSession.shared.dataTask(with: request) { data, response, err in
            guard let data = data, err == nil else {
                self.appError = AppError(description: err?.localizedDescription)
                return
            }
            
            do {
                let resp = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as! Dictionary<String, Any>
                print(resp)
                if resp["requestStatus"] as! String == RequestStatus.Pending.rawValue {
                    DispatchQueue.main.async {
                        self.updateStatus(taskId: taskId)  //  Recursive call
                        return
                    }
                }
            } catch let e {
                DispatchQueue.main.async {
                    self.appError = AppError(description: e.localizedDescription)
                    print("line 377:", e)
                }
            }
            
            do {
                let result = try JSONDecoder().decode(TaskStatus.self, from: data)
                
                DispatchQueue.main.async {
                    self.generationProgress = result.task_result
                    print(self.generationProgress)
                    self.updateStatus(taskId: taskId)  //  Recursive call
                }
            } catch let e {
                DispatchQueue.main.async {
                    if tryNum < 3 {
                        self.updateStatus(taskId: taskId, tryNum: tryNum + 1)  //  Recursive call
                    } else {
                        self.appError = AppError(description: e.localizedDescription)
                        self.generationProgress = nil
                        print("line 391:", e)
                    }
                }
            }
            
        }.resume()
    }
    
    func fetchMashup(uuid: UUID, onCompletion: ((Audio) -> ())?) {
        guard let taskId = self.generationTaskId else { return }
        
        guard let url = URL(string: Config.SERVER + HttpRequests.RESULT + "/" + taskId) else {
            self.appError = AppError(description: "Url invalid")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Application/json", forHTTPHeaderField: "Content-Type")
        
        
        URLSession.shared.dataTask(with: request) { data, response, err in
            guard let data = data, err == nil else {
                self.appError = AppError(description: err?.localizedDescription)
                return
            }
            
            do {
                let result = try JSONDecoder().decode(TaskResult.self, from: data)
                guard let audioData = Data(base64Encoded: result.task_result.snd) else {
                    self.appError = AppError(description: "Cannot convert snd from base64 data")
                    return
                }
                
                let tempFile = MashupFileManager.saveAudio(data: audioData, name: uuid.uuidString, ext: "aac")
                
                if let tempFile = tempFile {
                    DispatchQueue.main.async {
                        self.tempo = result.task_result.tempo
                        self.mashupAudio = Audio(file: tempFile)
                        self.generationTaskId = nil
                        self.readyToPlay = true
                        
                        guard let onCompletion = onCompletion else { return }
                        onCompletion(self.mashupAudio!)
                    }
                } else {
                    self.appError = AppError(description: "Failed to save audio")
                }
            } catch let e {
                self.appError = AppError(description: e.localizedDescription)
                print(e)
            }
            
        }.resume()
        
    }
    
}
