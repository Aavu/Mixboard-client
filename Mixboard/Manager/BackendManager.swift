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
    @Published var downloadStatus = [String: TaskStatus.Status]()
    @Published var isDownloading = false
    
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
//                        if let result = resp["task_result"] {
//                            let str = String(describing: result)
//                            if let err = Int(str) {
//                                if err != 0 {
//                                    DispatchQueue.main.async {
//                                        completion(nil, NSError(domain: "This song cannot be downloaded. Please choose a different song or version", code: 151))
//                                    }
//                                    return
//                                }
//
//                            } else {
//                                print("Cannot convert string (\(str)) to Int")
//                                completion(nil, NSError(domain: "Conversion Error", code: 500))
//                                return
//                            }
//                        } else {
//                            print("Task result empty")
//                        }
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
    
    func sendGenerateRequest(uuid: String, lastSessionId: String?, layout: Layout, onCompletion:@escaping (Audio?, Layout?, Error?) -> ()) {
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
            guard let data = data, err == nil else {
                print("Function: \(#function), line: \(#line),", err as Any)
                self.isGenerating = false
                onCompletion(nil, nil, err)
                return
            }
            
            do {
                let resp = try JSONSerialization.jsonObject(with: data) as! Dictionary<String, String>
                DispatchQueue.main.async {
                    self.generationTaskId = resp["task_id"]

                    guard let taskId = self.generationTaskId else {
                        onCompletion(nil, nil, NSError(domain: "TaskId is Nil", code: 115))
                        return
                    }
                    
                    self.generationStatus = TaskStatus.Status(progress: 5, description: "Hold On! Creating some magic...")
                    
                    self.updateStatus(taskId: taskId, status: self.generationStatus!) { status in
                        DispatchQueue.main.async {
                            self.generationStatus = status
                        }
                    } completion: { status, err in
                        DispatchQueue.main.async {
                            self.generationStatus = status
                        }
                        if let err = err {
                            onCompletion(nil, nil, err)
                        }
                    }

                    self.timer = Timer
                        .publish(every: 0.5, on: .current, in: .common)
                        .autoconnect()
                        .sink(receiveValue: { value in
                            if self.generationStatus?.progress == 100 && self.isGenerating {
                                self.fetchMashup(uuid: uuid) { audio, err in
                                    if let err = err {
                                        onCompletion(nil, nil, err)
                                        self.timer = nil
                                        self.isGenerating = false
                                        return
                                    }
                                    
                                    self.timer = nil
                                    self.isGenerating = false
                                    
                                    // Currently it reflects the layout that was created by the user. This is a placeholder because, the server will need to add info about the exact samples it chose so as to be able to retrieve later from history and generate the same mashup
                                    onCompletion(audio, layout, nil)
                                    return
                                }
                            }
                        })
                }
            } catch let e {
                print("Function: \(#function), line: \(#line),", e)
                self.isGenerating = false
                onCompletion(nil, nil, err)
            }
            
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
                        
                        onCompletion(Audio(file: tempFile), nil)
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
