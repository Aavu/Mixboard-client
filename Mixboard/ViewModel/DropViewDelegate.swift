//
//  DropViewDelegate.swift
//  Mashup
//
//  Created by Raghavasimhan Sankaranarayanan on 10/15/22.
//

import Foundation
import SwiftUI

struct DropViewDelegate: DropDelegate {    
    @Binding var position: CGFloat
    
    var didDrop: (String, CGFloat) -> ()
    
    func performDrop(info: DropInfo) -> Bool {
        if let item = info.itemProviders(for: [.url]).first {
            let _ = item.loadObject(ofClass: URL.self) { value, err in
                guard let id = value?.absoluteString else {
                    return
                }
                
                DispatchQueue.main.async {
                    didDrop(id, info.location.x)
                }
            }
            
            return true
        }
        return false
    }
    
//    func dropUpdated(info: DropInfo) -> DropProposal? {
//        print(info.location.x)
//        return nil
//    }
}
