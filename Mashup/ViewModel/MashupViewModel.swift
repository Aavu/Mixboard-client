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
    
    @Published var readyToPlay = false
    
    @Published var isFocuingSongs = false
    
    
    @Published var dragLocation = Dictionary<String, CGPoint>()
    
    static let TOTAL_BEATS = 32
    
    @Published var lastBeat = TOTAL_BEATS
    @Published var generationProgress:Int = 0
    
    var generationTaskId: String?
    var mashupAudioFile: URL?
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
//        setSelected(uuid: region.id, isSelected: false)
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
    
    func updateRegion(lane: Lane, id: UUID, x: Int, length: Int) {
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
    
    func deleteRegionsFor(songId: String) {
        for lane in Lane.allCases {
            if let regions = layoutInfo.lane[lane.rawValue]?.layout {
                for (idx, region) in regions.enumerated() {
                    if region.item.id == songId {
//                        print(idx, layoutInfo.lane[lane.rawValue]!.layout.count)
//                        layoutInfo.lane[lane.rawValue]!.layout.remove(at: idx)
                        removeRegion(lane: lane, id: region.id)
                    }
                }
            }
        }
        isEmpty = isCanvasEmpty()
        updateLastBeat()
    }
    
    func restoreFromHistory(history: History) {
        self.mashupAudioFile = history.audioFilePath

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
    
    func sendGenerateRequest(uuid: UUID, onCompletion: ((URL?, Layout) -> ())?) {
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
                    mashupAudioFile = nil
                    tempo = nil
                    generationTaskId = resp["task_id"]
                    
                    readyToPlay = false
                    
                    guard let taskId = self.generationTaskId else { return }
                    
                    self.generationProgress = 0
                    self.updateStatus(taskId: taskId)
                    
                    timer = Timer
                        .publish(every: 0.5, on: .current, in: .common)
                        .autoconnect()
                        .sink(receiveValue: { value in
                            if self.generationProgress == 100 && self.isGenerating {
                                self.fetchMashup(uuid: uuid) { url in
                                    if self.mashupAudioFile != nil {
                                        self.timer = nil
                                        self.isGenerating = false
                                        
                                        guard let onCompletion = onCompletion else { return }
                                        onCompletion(self.mashupAudioFile, self.layoutInfo)
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
    
    func updateStatus(taskId: String) {
        if self.generationProgress == 100 { return }
        
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
                    }
                }
            } catch let e {
                DispatchQueue.main.async {
                    self.appError = AppError(description: e.localizedDescription)
                }
            }
            
            do {
                let result = try JSONDecoder().decode(TaskStatus.self, from: data)
                
                DispatchQueue.main.async {
                    self.generationProgress = result.task_result.progress
                    print(self.generationProgress)
                    self.updateStatus(taskId: taskId)  //  Recursive call
                }
            } catch let e {
                DispatchQueue.main.async {
                    self.appError = AppError(description: e.localizedDescription)
                }
            }
            
        }.resume()
    }
    
    func fetchMashup(uuid: UUID, onCompletion: ((URL?) -> ())?) {
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
                
                DispatchQueue.main.async {
                    self.tempo = result.task_result.tempo
                    self.mashupAudioFile = tempFile
                    self.generationTaskId = nil
                    self.readyToPlay = true

                    guard let onCompletion = onCompletion else { return }
                    onCompletion(self.mashupAudioFile)
                }
            } catch let e {
                self.appError = AppError(description: e.localizedDescription)
            }
            
        }.resume()
        
    }
    
}
