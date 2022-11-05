//
//  BarAxisView.swift
//  Mashup
//
//  Created by Raghavasimhan Sankaranarayanan on 10/16/22.
//

import SwiftUI

struct BarAxisView: View {
    
    let width: CGFloat
    let height: CGFloat
    
    let numBeats: Int
    
    var body: some View {
        let len = Int(numBeats / 4)
        ZStack(alignment: .leading) {
            HStack(alignment: .bottom) {
                ForEach((0..<len), id: \.self) { i in
                    Rectangle().frame(width: width, height: height).foregroundColor(.SecondaryAccentColor)
                    Spacer()
                    ForEach((0..<3)) { j in
                        Rectangle().frame(width: width, height: height / 2.5).foregroundColor(.SecondaryAccentColor).opacity(0.35)
                        Spacer()
                    }
                }
            }
            
            HStack(alignment: .bottom, spacing: 0) {
                ForEach((0..<len), id: \.self) { i in
                    Text(String((i * 4) + 1))
                        .foregroundColor(.SecondaryAccentColor)
                        .font(.footnote)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .offset(x:4, y:-6)
                }
            }
        }
    }
}

struct BarAxisView_Previews: PreviewProvider {
    static var previews: some View {
        BarAxisView(width: 2, height: 10, numBeats: 32)
    }
}
