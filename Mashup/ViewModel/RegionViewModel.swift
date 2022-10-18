//
//  RegionViewModel.swift
//  Mashup
//
//  Created by Raghavasimhan Sankaranarayanan on 10/16/22.
//

import Foundation

class LaneViewModel: ObservableObject {
    @Published var regions = Dictionary<UUID, Region>()
    @Published var selected = Dictionary<UUID, Bool>()
    
    let lane: Lane
    
    init(lane: Lane) {
        self.lane = lane
    }
    
    func isEmpty() -> Bool {
        return regions.count == 0
    }
    
    func addRegion(region: Region) -> UUID {
        let id = UUID()
        self.regions[id] = region
        return id
    }
    
    func removeRegion(id: UUID) {
        regions.removeValue(forKey: id)
    }
    
    func updateRegion(id: UUID, x: Int, length: Int) {
        regions[id]?.x = x
        regions[id]?.w = length
    }
    
    func setSelected(uuid: UUID, isSelected: Bool) {
        selected[uuid] = isSelected
    }
    
    func isSelected(uuid: UUID) -> Bool {
        return selected[uuid] ?? false
    }
}
