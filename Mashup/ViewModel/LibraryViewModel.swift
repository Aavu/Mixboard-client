//
//  LibraryViewModel.swift
//  Mashup
//
//  Created by Raghavasimhan Sankaranarayanan on 10/14/22.
//

import Foundation
import Combine

class LibraryViewModel: ObservableObject {
    @Published var library: Library?
    private var unfilteredSongs = [Song]()
    @Published var songs = [Song]()
    
    @Published var searchText = ""
    
    private var cancellables = Set<AnyCancellable>()
    init() {
        update()
        addSubscribers()
    }
    
    func addSubscribers() {
        $searchText
            .debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
            .map { (txt) -> [Song] in
                guard !txt.isEmpty else {
                    return self.unfilteredSongs
                }
                
                let lowerTxt = txt.lowercased().trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                
                return self.unfilteredSongs.filter { song in
                    return song.name?.lowercased().contains(lowerTxt) ?? false ||
                    song.album?.lowercased().contains(lowerTxt) ?? false ||
                    song.artist?.lowercased().contains(lowerTxt) ?? false
                }
            }
            .sink { filteredSongs in
                self.songs = filteredSongs
            }
            .store(in: &cancellables)
    }
    
    func loadExampleData() -> Bool {
        guard let url = Bundle.main.url(forResource: "libraryExample", withExtension: "json")
        else {
            print("Json file not found")
            return false
        }
        
        do {
            let data = try Data(contentsOf: url)
            self.library = try JSONDecoder().decode(Library.self, from: data)
        } catch let e {
            print(e)
            return false
        }
        
//        print(self.library?.items["5Wsj5AFp99VB4XaOg1Druw"]?.name)
        return true
    }
    
    func update(didUpdate: (() -> ())? = nil) {
        guard let url = URL(string: Config.SERVER + HttpRequests.TRACK_LIST) else {
            print("Error: Url invalid")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        URLSession.shared.dataTask(with: request) { data, response, err in
            guard let data = data, err == nil else {
                return
            }
            
            do {
//                let resp = try JSONSerialization.jsonObject(with: data)
//                print(resp)
                let lib = try JSONDecoder().decode(Library.self, from: data)
                DispatchQueue.main.async {
                    self.library = lib
                    self.getSongs()
                    guard let didUpdate = didUpdate else { return }
                    didUpdate()
                }
            } catch let e{
                print("error fetching library")
                print(e)
            }
            
        }.resume()
    }
    
    private func getSongs() {
        guard let library = self.library else { return }
        for (_, v) in library.items {
            self.songs.append(v)
            self.unfilteredSongs.append(v)
        }
    }
    
    func getSong(songId: String) -> Song {
        guard let library = self.library else { return Song(id: songId) }
        return library.items[songId] ?? Song(id: songId)
    }
    
}
