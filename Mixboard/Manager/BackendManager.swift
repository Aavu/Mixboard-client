//
//  BackendManager.swift
//  Mixboard
//
//  Created by Raghavasimhan Sankaranarayanan on 11/10/22.
//

import Foundation
import Combine
import SwiftUI

class BackendManager: ObservableObject {
    
    public static let shared = BackendManager()
    
    @AppStorage("email") private var email: String?
    
    @Published var isGenerating = false
    var generationTaskId: String?

    @Published var generationStatus: TaskStatus.Status?
    @Published var regionData: TaskData.MBData?
    @Published var downloadStatus = [String: TaskStatus.Status]()
    @Published var isDownloading = false
    
    
    private var numRegionsFetched = 0
    private let fetchRegionsQueue = DispatchQueue(label:"fetchRegionsQueue")
    var timer: AnyCancellable?
    
    func addSong(songId: String, onCompletion:@escaping (Error?) -> ()) {
        let url = URL(string: Config.SERVER + HttpRequests.ADD_SONG)!
        
        NetworkManager.request(url: url, type: .POST, httpbody: try? JSONSerialization.data(withJSONObject: ["url" : songId, "email": email])) { completion in
            switch completion {
            case .failure(let e):
                print("Function: \(#function), line: \(#line),", e)
                onCompletion(e)
            case .finished:
                break
            }
        } completion: { (response:Dictionary<String, String>?) in
            if let taskId = response?["task_id"] {
                self.isDownloading = true
                if self.downloadStatus[songId] == nil {
                    self.downloadStatus[songId] = TaskStatus.Status(progress: 5, description: "Waiting in queue")
                }
                
                self.updateStatus(taskId: taskId, status: self.downloadStatus[songId]!) { status in
                    self.downloadStatus[songId] = status
                } completion: { status, err in
                    DispatchQueue.main.async {
                        self.isDownloading = false
                        self.downloadStatus.removeValue(forKey: songId)
                        onCompletion(err)
                    }
                }
            } else {
                onCompletion(NSError(domain: "taskid or response is nil", code: 120))
            }
        }
    }
    
    func removeSong(songId: String, onCompletion: @escaping (Error?) -> ()) {
        let url = URL(string: Config.SERVER + HttpRequests.REMOVE_SONG)!
        
        NetworkManager.request(url: url, type: .POST, httpbody: try? JSONSerialization.data(withJSONObject: ["url" : songId, "email": email])) { completion in
            switch completion {
            case .failure(let e):
                print("Function: \(#function), line: \(#line),", e)
                onCompletion(e)
            case .finished:
                break
            }
        } completion: { (response: Dictionary<String, String>?) in
            onCompletion(nil)
        }
    }
    
    func fetchRegion(regionId: String, tryNum: Int = 0, completion: @escaping (TaskData.MBData?, Error?)->()) {
        let url = URL(string: Config.SERVER + HttpRequests.REGION + "/" + regionId)!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Application/json", forHTTPHeaderField: "Content-Type")
        
        URLSession.shared.dataTask(with: request) {data, response, err in
            guard let data = data, err == nil else {
                if let err = err {
                    print("Function: \(#function), line: \(#line),", err)
                    if err._code == -1001 {
                        if tryNum < 100 {
                            print("Function: \(#function), line: \(#line),", "Request timeout: trying again...")
                            self.fetchRegion(regionId: regionId, tryNum: tryNum + 1, completion: completion)
                            return
                        }
                    }
                    
                    DispatchQueue.main.async {
                        print("Function: \(#function), line: \(#line),", err as Any)
                        completion(nil, err)
                        return
                    }
                }
                return
            }
            
            do {
                let data = try JSONDecoder().decode(TaskData.MBData.self, from: data)
                if data.valid {
                    completion(data, nil)
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        self.fetchRegion(regionId: regionId, tryNum: tryNum, completion: completion) // Recursive call
                    }
                }
                
                //                if let stat = RequestStatus(rawValue: resp["requestStatus"] as! String) {
                //                    switch stat {
                //                    case .Progress:
                //                        let result = try JSONDecoder().decode(TaskData.self, from: data)
                //                        DispatchQueue.main.async {
                //                            statusCallback(result.task_result)
                //                            self.updateRegionData(regionId: regionId, statusCallback: statusCallback, completion: completion)  //  Recursive call
                //                        }
                //                        return
                //                    case .Pending:
                //                        let result = try JSONDecoder().decode(TaskData.self, from: data)
                //                        DispatchQueue.main.async {
                //                            statusCallback(result.task_result)
                //                            self.updateRegionData(regionId: regionId, statusCallback: statusCallback, completion: completion)  //  Recursive call
                //                        }
                //
                //                        return
                //                    case .Success:
                //                        DispatchQueue.main.async {
                //                            completion(nil)
                //                        }
                //                    case .Failure:
                //                        DispatchQueue.main.async {
                //                            completion(NSError(domain: "This song cannot be downloaded. Please choose a different song or version", code: 151))
                //                        }
                //                        return
                //                    }
                //                }
            } catch let e {
                DispatchQueue.main.async {
                    if tryNum < 3 {
                        self.fetchRegion(regionId: regionId, tryNum: tryNum + 1, completion: completion)  //  Recursive call
                    } else {
                        print("Function: \(#function), line: \(#line),", e)
                        completion(nil, NSError(domain: "The region cannot be downloaded.", code: 152))
                    }
                }
            }
            
        }.resume()
    }
    
    func updateRegionData(regionIds: [String], tryNum: Int = 0, statusCallback: @escaping (TaskData.MBData) -> (), completion: @escaping (Error?)->()) {
        for regionId in regionIds {
            fetchRegion(regionId: regionId) { data, err in
                if let err = err {
                    print("Function: \(#function), line: \(#line),", err)
                    completion(err)
                    return
                }
                
                if let data = data {
                    self.fetchRegionsQueue.sync {
                        self.numRegionsFetched += 1
                    }
                    statusCallback(data)
                }
                
                print("Num regions fetched: \(self.numRegionsFetched), out of \(regionIds.count)")
                
                var temp = 0
                self.fetchRegionsQueue.sync {
                    temp = self.numRegionsFetched
                }
                
                if temp >= regionIds.count {
                    self.fetchRegionsQueue.sync {
                        self.numRegionsFetched = 0
                    }
                    completion(nil)
                    return
                }
            }
        }
    }
    
    func updateStatus(taskId: String, status: TaskStatus.Status, tryNum: Int = 0, statusCallback: @escaping (TaskStatus.Status?) -> (), completion: @escaping ( TaskStatus.Status?, Error?)->()) {
        if status.progress == 100 { return }
        
        let url = URL(string: Config.SERVER + HttpRequests.STATUS + "/" + taskId)!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Application/json", forHTTPHeaderField: "Content-Type")
        
        URLSession.shared.dataTask(with: request) { data, response, err in
            guard let data = data, err == nil else {
                if let err = err {
                    print("Function: \(#function), line: \(#line),", err)
                    if err._code == -1001 {
                        if tryNum < 100 {
                            print("Function: \(#function), line: \(#line),", "Request timeout: trying again...")
                            self.updateStatus(taskId: taskId, status: status, tryNum: tryNum + 1, statusCallback: statusCallback, completion: completion)
                            return
                        }
                    }
                    
                    DispatchQueue.main.async {
                        print("Function: \(#function), line: \(#line),", err as Any)
                        completion(nil, err)
                        return
                    }
                }
                return
            }
            
            do {
                let resp = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as! Dictionary<String, Any>
                if let stat = RequestStatus(rawValue: resp["requestStatus"] as! String) {
                    switch stat {
                    case .Progress:
                        let result = try JSONDecoder().decode(TaskStatus.self, from: data)
                        DispatchQueue.main.async {
                            statusCallback(result.task_result)
                            self.updateStatus(taskId: taskId, status: result.task_result, statusCallback: statusCallback, completion: completion)  //  Recursive call
                        }
                        return
                    case .Pending:
                        let result = try JSONDecoder().decode(TaskStatus.self, from: data)
                        DispatchQueue.main.async {
                            statusCallback(result.task_result)
                            self.updateStatus(taskId: taskId, status: result.task_result, statusCallback: statusCallback, completion: completion)  //  Recursive call
                        }

                        return
                    case .Success:
                        DispatchQueue.main.async {
                            completion(TaskStatus.Status(progress: 100, description: "Completed!"), nil)
                        }
                    case .Failure:
                        DispatchQueue.main.async {
                            completion(nil, NSError(domain: "This song cannot be downloaded. Please choose a different song or version", code: 151))
                        }
                        return
                    }
                }
            } catch let e {
                DispatchQueue.main.async {
                    if tryNum < 3 {
                        self.updateStatus(taskId: taskId, status: status, tryNum: tryNum + 1, statusCallback: statusCallback, completion: completion)  //  Recursive call
                    } else {
                        print("Function: \(#function), line: \(#line),", e)
                        completion(nil, NSError(domain: "This song cannot be downloaded. Please choose a different song or version", code: 151))
                    }
                }
            }
            
        }.resume()
    }
    
    
    func sendGenerateRequest(uuid: String, lastSessionId: String?, layout: Layout, regionIds: [String], statusCallback: @escaping (Audio?) -> (), onCompletion:@escaping (Layout?, Error?) -> ()) {
        let url = URL(string: Config.SERVER + HttpRequests.GENERATE)!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Application/json", forHTTPHeaderField: "Content-Type")
        
        if let email = email {
            let generateRequest = GenerateRequest(data: layout.lane, email: email, sessionId: uuid, lastSessionId: lastSessionId)
            request.httpBody = try? JSONEncoder().encode(generateRequest)
        }
        
        isGenerating = true
        
        URLSession.shared.dataTask(with: request) { data, response, err in
            guard let _ = data, err == nil else {
                print("Function: \(#function), line: \(#line),", err as Any)
                self.isGenerating = false
                onCompletion(nil, err)
                return
            }
            
            DispatchQueue.main.async {
                self.generationStatus = TaskStatus.Status(progress: 5, description: "Hold On! Creating some magic...")
            }
            
            self.updateRegionData(regionIds: regionIds) { mbData in
                print("fetched: \(mbData.id)")
                
                guard let audioData = Data(base64Encoded: mbData.snd) else {
                    onCompletion(nil, NSError(domain: "Audio data cannot be decoded", code: 110))
                    return
                }
                
                let tempFile = MashupFileManager.saveAudio(data: audioData, name: mbData.id, ext: "aac")
                
                if let tempFile = tempFile {
                    statusCallback(Audio(file: tempFile, position: mbData.position, tempo: mbData.tempo))
                } else {
                    onCompletion(nil, NSError(domain: "Unable to save audio", code: 111))
                }
            } completion: { err in
                DispatchQueue.main.async {
                    self.isGenerating = false
                    if let err = err {
                        onCompletion(layout, err)
                    }
                    
                    onCompletion(layout, nil)
                }
            }
            
//            do {
////                let resp = try JSONSerialization.jsonObject(with: data) as! Dictionary<String, String>
//
//            } catch let e {
//                print("Function: \(#function), line: \(#line),", e)
//                self.isGenerating = false
//                onCompletion(nil, err)
//            }
            
        }.resume()
    }
    
    func fetchMashup(uuid: String, tryNum: Int = 0, onCompletion: @escaping (Audio?, Error?) -> ()) {
        guard let taskId = self.generationTaskId else { return }
        
        let url = URL(string: Config.SERVER + HttpRequests.RESULT + "/" + taskId)!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Application/json", forHTTPHeaderField: "Content-Type")
        
        
        URLSession.shared.dataTask(with: request) { data, response, err in
            guard let data = data, err == nil else {
                print("Function: \(#function), line: \(#line),", err as Any)
                onCompletion(nil, err)
                return
            }
            
            do {
                let result = try JSONDecoder().decode(TaskResult.self, from: data)
                guard let audioData = Data(base64Encoded: result.task_result.snd) else {
                    onCompletion(nil, NSError(domain: "Audio data cannot be decoded", code: 110))
                    return
                }
                
                let tempFile = MashupFileManager.saveAudio(data: audioData, name: uuid, ext: "aac")
                
                if let tempFile = tempFile {
                    DispatchQueue.main.async {
                        self.generationTaskId = nil
                        
                        onCompletion(Audio(file: tempFile, position: 0, sampleRate: 44100), nil)
                    }
                } else {
                    onCompletion(nil, NSError(domain: "Unable to save audio", code: 111))
                }
            } catch let e {
                DispatchQueue.main.async {
                    if tryNum < 3 {
                        self.fetchMashup(uuid: uuid, tryNum: tryNum + 1, onCompletion: onCompletion)  //  Recursive call
                    } else {
                        print("Function: \(#function), line: \(#line),", e)
                        onCompletion(nil, e)
                    }
                }
            }
            
        }.resume()
        
    }
}
