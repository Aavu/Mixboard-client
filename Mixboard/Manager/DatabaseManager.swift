//
//  DatabaseManager.swift
//  Mixboard
//
//  Created by Raghavasimhan Sankaranarayanan on 11/9/22.
//

import Foundation
import Firebase

class DatabaseManager: ObservableObject {
    
    private var historyRef: CollectionReference?
    private var spotifyRef: DocumentReference?
    private var userRef: DocumentReference?
    
    init(userId: String? = nil) {
        let db = Firestore.firestore()
        if let userId = userId {
            historyRef = db.collection("users").document(userId).collection("history")
            userRef = db.collection("users").document(userId)
        }
        spotifyRef = db.collection("spotify").document("credentials")
    }
    
    func removeSpotifyCredential() {
        if let userRef = userRef {
            for type in Spotify.GrantType.allCases {
                userRef.updateData([getTypeString(for: type): FieldValue.delete()])
            }
        }
    }
    
    func getSpotifyClient(completion: @escaping (Spotify.ClientIdSecret) -> ()) {
        if let spotifyRef = spotifyRef {
            spotifyRef.addSnapshotListener({ snapshot, err in
                if let err = err {
                    print("Function: \(#function), line: \(#line),", err)
                    return
                }
                
                if let snapshot = snapshot {
                    do {
                        let client = try snapshot.data(as: Spotify.ClientIdSecret.self)
                        completion(client)
                    } catch (let e) {
                        print("Function: \(#function), line: \(#line),", e)
                    }
                } else {
                    print("Function: \(#function), line: \(#line),", "snapshot is nil")
                }
            })
        } else {
            print("Function: \(#function), line: \(#line),", "spotify ref is nil")
        }
    }
    
    func setSpotifyAuthCredential(cred: Spotify.Credential, type: Spotify.GrantType, completion: @escaping (Error?) -> ()) {
        if let userRef = userRef {
            do {
                let data = try JSONEncoder().encode(cred)
                let json = try JSONSerialization.jsonObject(with: data)
                
                userRef.updateData([getTypeString(for: type): json], completion: completion)
            } catch (let err) {
                completion(err)
            }
        } else {
            completion(NSError(domain: "userRef is nil", code: 350))
        }
    }
    
    func getTypeString(for type: Spotify.GrantType) -> String {
        switch type {
        case .code:
            return "userCredential"
        case .client:
            return "clientCredential"
        }
    }
    
    func getSpotifyAuthCredential(for type:Spotify.GrantType, completion: @escaping (Spotify.Credential?, Error?) -> ()) {
        if let userRef = userRef {
            userRef.getDocument { doc, err in
                guard let userCred = doc?.get(self.getTypeString(for: type)) else {
                    completion(nil, nil)
                    return
                }
                do {
                    let json = userCred as! [String : Any]
                    let data = try JSONSerialization.data(withJSONObject: json)
                    let cred = try JSONDecoder().decode(Spotify.Credential.self, from: data)
                    completion(cred, nil)
                    return
                } catch (let e) {
                    print("Function: \(#function), line: \(#line),", e)
                    completion(nil, e)
                    return
                }
                
            }
        } else {
            completion(nil, NSError(domain: "userRef is nil", code: 350))
        }
    }
    
    func setSpotifyAuthCode(code: String, completion: @escaping (Error?) -> ()) {
        if let userRef = userRef {
            userRef.updateData(["spotifyAuthCode": code], completion: completion)
            return
        } else {
            completion(NSError(domain: "userRef is nil", code: 350))
        }
    }
    
    func getSpotifyAuthCode(completion: @escaping (String?) -> ()) {
        if let userRef = userRef {
            userRef.getDocument(completion: { doc, err in
                let temp = doc?.get("spotifyAuthCode") as? String
                completion(temp)
                return
            })
        } else {
            completion(nil)
        }
    }
    
    func add(history: History) {
        do {
            if let uuid = history.id {
                let _ = try historyRef?.document(uuid).setData(from: history)
            }
        } catch (let err) {
            print("Function: \(#function), line: \(#line),", err)
        }
    }
    
    func remove(history: History) {
        if let uuid = history.id {
            historyRef?.document(uuid).delete()
        }
    }
    
    func getHistories(completion: @escaping ([History]) -> ()) {
        if let historyRef = historyRef {
            historyRef.addSnapshotListener({ snapshot, err in
                if let err = err {
                    print("Function: \(#function), line: \(#line),", err)
                    return
                }
                
                if let snapshot = snapshot {
                    let histories = snapshot.documents.compactMap { doc in
                        do {
                            var history = try doc.data(as: History.self)
                            
                            // Remove audio path if the file does not exist
                            if let audio = history.audio {
                                if !MashupFileManager.exists(file: audio.file) {
                                    history.audio = nil
                                }
                            }
                            return history
                        } catch (let e) {
                            print("Function: \(#function), line: \(#line),", e)
                        }
                        
                        return nil
                    }
                    
                    completion(histories)
                    return
                } else {
                    print("Function: \(#function), line: \(#line),", "snapshot is nil")
                }
            })
        } else {
            print("Function: \(#function), line: \(#line),", "History ref is nil")
        }
        
        completion([])
    }
}
