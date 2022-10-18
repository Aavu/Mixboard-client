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
    
    @Published var layoutInfo: Layout
    @Published var isGenerating = false
    @Published var isEmpty = true
    
    @Published var readyToPlay = false
    
    @Published var isFocuingSongs = false
    
    static let TOTAL_BEATS = 32
    
    @Published var lastBeat = TOTAL_BEATS
    @Published var generationProgress:Int = 0
    
    var generationTaskId: String?
    var mashupAudioFile: URL?
    var tempo: Float?
    
    var timer: AnyCancellable?
    
    init() {
        self.layoutInfo = Layout(vocals: Layout.Track(), other: Layout.Track(), bass: Layout.Track(), drums: Layout.Track())
        self.createLibrary()
    }
    
    func createLibrary() {
        guard let url = URL(string: Config.SERVER + HttpRequests.ROOT) else {
            print("Error: Url invalid")
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
    
    func updateRegions(lane: Lane, regions: [Region]) {
        switch lane {
        case .Vocals:
            layoutInfo.vocals.layout = regions
        case .Other:
            layoutInfo.other.layout = regions
        case .Bass:
            layoutInfo.bass.layout = regions
        case .Drums:
            layoutInfo.drums.layout = regions
        }
        
        
        isEmpty = layoutInfo.vocals.layout.count == 0 && layoutInfo.other.layout.count == 0 && layoutInfo.bass.layout.count == 0 && layoutInfo.drums.layout.count == 0
        
        var lastBeatTemp = 0
        for region in layoutInfo.vocals.layout {
            lastBeatTemp = max(lastBeatTemp, region.x + region.w)
        }
        
        for region in layoutInfo.other.layout {
            lastBeatTemp = max(lastBeatTemp, region.x + region.w)
        }
        
        for region in layoutInfo.bass.layout {
            lastBeatTemp = max(lastBeatTemp, region.x + region.w)
        }
        
        for region in layoutInfo.drums.layout {
            lastBeatTemp = max(lastBeatTemp, region.x + region.w)
        }
        
        lastBeat = min(MashupViewModel.TOTAL_BEATS, lastBeatTemp)
    }
    
    
    func loadExampleData() -> Bool {
        guard let url = Bundle.main.url(forResource: "generateRequestExample", withExtension: "json")
        else {
            print("Json file not found")
            return false
        }
        
        do {
            let data = try Data(contentsOf: url)
            self.layoutInfo = try JSONDecoder().decode(Layout.self, from: data)
        } catch let e {
            print(e)
            return false
        }
        
        return true
    }
    
    func sendGenerateRequest() {
        guard let url = URL(string: Config.SERVER + HttpRequests.GENERATE) else {
            print("Error: Url invalid")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Application/json", forHTTPHeaderField: "Content-Type")
        
        request.httpBody = try? JSONEncoder().encode(self.layoutInfo)
        
        if let body = request.httpBody {
            let out = try? JSONSerialization.jsonObject(with: body)
            print(out as Any)
        }
        
        URLSession.shared.dataTask(with: request) { data, response, err in
            guard let data = data, err == nil else {
                return
            }
            
            do {
                let resp = try JSONSerialization.jsonObject(with: data) as! Dictionary<String, String>
                DispatchQueue.main.async { [self] in
                    mashupAudioFile = nil
                    tempo = nil
                    generationTaskId = resp["task_id"]
                    
                    isGenerating = true
                    readyToPlay = false
                    
                    guard let taskId = self.generationTaskId else { return }
                    
                    self.generationProgress = 0
                    self.updateStatus(taskId: taskId)
                    
                    timer = Timer
                        .publish(every: 0.5, on: .current, in: .common)
                        .autoconnect()
                        .sink(receiveValue: { value in
                            if self.generationProgress == 100 {
                                self.fetchMashup()
                                
                                if self.mashupAudioFile != nil {
                                    self.timer = nil
                                    self.isGenerating = false
                                }
                            }
                        })
                }
            } catch let e {
                print(e)
            }
            
        }.resume()
    }
    
    func updateStatus(taskId: String) {
        if self.generationProgress == 100 { return }
        
        guard let url = URL(string: Config.SERVER + HttpRequests.STATUS + "/" + taskId) else {
            print("Error: Url invalid")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Application/json", forHTTPHeaderField: "Content-Type")
        
        URLSession.shared.dataTask(with: request) { data, response, err in
            guard let data = data, err == nil else {
                return
            }
            
            do {
//                let resp = try JSONSerialization.jsonObject(with: data)
//                print(resp)
                let result = try JSONDecoder().decode(TaskStatus.self, from: data)
                
                DispatchQueue.main.async {
                    self.generationProgress = result.task_result.progress
                    print(self.generationProgress)
                    self.updateStatus(taskId: taskId)  //  Recursive call
                }
            } catch let err {
                print("Error decoding task status: ", err)
            }
            
        }.resume()
    }
    
    func fetchMashup() {
        guard let taskId = self.generationTaskId else { return }
        
        guard let url = URL(string: Config.SERVER + HttpRequests.RESULT + "/" + taskId) else {
            print("Error: Url invalid")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Application/json", forHTTPHeaderField: "Content-Type")
        
        
        URLSession.shared.dataTask(with: request) { data, response, err in
            guard let data = data, err == nil else {
                return
            }
            
            do {
                let result = try JSONDecoder().decode(TaskResult.self, from: data)
                guard let audioData = Data(base64Encoded: result.task_result.snd) else {
                    print("Error converting to Data")
                    return
                }
                
                let tempFile = MashupFileManager.saveAudio(data: audioData, name: "test", ext: "aac")
                
                DispatchQueue.main.async {
                    self.tempo = result.task_result.tempo
                    self.mashupAudioFile = tempFile
                    self.generationTaskId = nil
                    self.readyToPlay = true
                }
            } catch let err {
                print(err)
            }
            
        }.resume()
        
    }
    
}
