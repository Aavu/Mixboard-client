//
//  Extensions.swift
//  Mashup
//
//  Created by Raghavasimhan Sankaranarayanan on 10/13/22.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers
import Swift

class MBOrderedDict<T1: Hashable, T2>: RandomAccessCollection, MutableCollection {
    subscript(position: Int) -> T2? {
        get {
            let key = self.indices[position]
            return self._data[key]
        }
        set(newValue) {
            if self.endIndex <= position {
                let key = self.indices[position]
                self._data[key] = newValue
            }
        }
    }
    
    var startIndex: Int
    
    var endIndex: Int
    
    var indices = [T1]() {
        didSet {
            endIndex = Swift.max(0, self.indices.count - 1)
        }
    }
    
    var values = [T2]()
    
    private var _data = [T1: T2]() {
        didSet {
            values = Array(self._data.values)
        }
    }
    
    init(_ data: [T1 : T2] = [T1: T2]()) {
        self.indices = Array(data.keys)
        self._data = data
        self.startIndex = 0
        self.endIndex = Swift.max(0, data.count - 1)
    }
    
    func index(_ i: Int, offsetBy distance: Int) -> Int {
        return i + distance
    }
    
    func distance(from start: Int, to end: Int) -> Int {
        return end - start
    }
    
    
    func get(valueFor key: T1) -> T2? {
        return self._data[key]
    }
    
    func update(value: T2, for key: T1) -> Bool {
        if get(valueFor: key) != nil {
            self._data[key] = value
            return true
        }
        return false
    }
    
    func set(value: T2, for key: T1) {
        self.indices.append(key)
        self._data[key] = value
    }
    
    func remove(key: T1) {
        removeKeyFromIndices(key: key)
        self._data[key] = nil
    }
    
    func remove(at idx: Int) {
        guard idx >= startIndex, idx <= endIndex else { return }
        let key = self.indices[idx]
        self.indices.remove(at: idx)
        self._data[key] = nil
    }
    
    private func removeKeyFromIndices(key: T1) {
        for i in (0...endIndex) {
            if self.indices[i] == key {
                self.indices.remove(at: i)
                return
            }
        }
    }
    
    func removeAll() {
        self._data = [T1: T2]()
        self.indices = [T1]()
    }
    
}


extension String {
    
    func fromBase64() -> String? {
        guard let data = Data(base64Encoded: self) else {
            return nil
        }
        
        return String(data: data, encoding: .utf8)
    }
    
    func toBase64() -> String {
        return Data(self.utf8).base64EncodedString()
    }
    
}

// Reference: https://medium.com/swlh/swiftui-read-the-average-color-of-an-image-c736adb43000
extension UIImage {
    /// Average color of the image, nil if it cannot be found
    var averageColor: UIColor? {
        // convert our image to a Core Image Image
        guard let inputImage = CIImage(image: self) else { return nil }
        
        // Create an extent vector (a frame with width and height of our current input image)
        let extentVector = CIVector(x: inputImage.extent.origin.x,
                                    y: inputImage.extent.origin.y,
                                    z: inputImage.extent.size.width,
                                    w: inputImage.extent.size.height)
        
        // create a CIAreaAverage filter, this will allow us to pull the average color from the image later on
        guard let filter = CIFilter(name: "CIAreaAverage",
                                    parameters: [kCIInputImageKey: inputImage, kCIInputExtentKey: extentVector]) else { return nil }
        guard let outputImage = filter.outputImage else { return nil }
        
        // A bitmap consisting of (r, g, b, a) value
        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: kCFNull!])
        
        // Render our output image into a 1 by 1 image supplying it our bitmap to update the values of (i.e the rgba of the 1 by 1 image will fill out bitmap array
        context.render(outputImage,
                       toBitmap: &bitmap,
                       rowBytes: 4,
                       bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                       format: .RGBA8,
                       colorSpace: nil)
        
        // Convert our bitmap images of r, g, b, a to a UIColor
        return UIColor(red: CGFloat(bitmap[0]) / 255,
                       green: CGFloat(bitmap[1]) / 255,
                       blue: CGFloat(bitmap[2]) / 255,
                       alpha: CGFloat(bitmap[3]) / 255)
    }
}


extension Color {
    public static let BgColor = Color("BgColor")
    public static let SecondaryBgColor = Color("SecondaryBgColor")
    public static let NeutralColor = Color("NeutralColor")
    public static let SecondaryAccentColor = Color("SecondaryAccentColor")
    public static let AccentColor = Color("AccentColor")
    public static let PureColor = Color("PureColor")
    public static let InvertedPureColor = Color("InvertedPureColor")
}

extension UIApplication {
    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// Refer: https://stackoverflow.com/questions/27259332/get-random-elements-from-array-in-swift
extension Collection {
    func choose(_ n: Int) -> ArraySlice<Element> { shuffled().prefix(n) }
}
