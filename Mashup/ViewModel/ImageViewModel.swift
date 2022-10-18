//
//  ImageViewModel.swift
//  Mashup
//
//  Created by Raghavasimhan Sankaranarayanan on 10/13/22.
//  Reference: https://www.youtube.com/watch?v=volfJt7mupo

import Foundation
import SwiftUI

class ImageViewModel: ObservableObject {
    @Published var image: UIImage?
    @Published var averageColor: Color
    
    var imageCache = ImageCache.getImageCache()
    
    let imageUrl: String?
    
    init(image: UIImage? = nil, imageUrl: String?) {
        self.image = image
        self.imageUrl = imageUrl
        self.averageColor = .blue
        loadImg()
    }
    
    func loadImg() {
        if loadImgFromCache() {
            return
        }
        loadImgFromURL()
    }
    
    private func loadImgFromCache() -> Bool {
        guard let imageUrl = imageUrl else { return false }
        
        guard let cachedImage = imageCache.getImage(forKey: imageUrl) else {
            return false
        }
        
        guard let cachedUrl = imageCache.getColor(forKey: imageUrl) else {
            return false
        }
        
        image = cachedImage
        averageColor = Color(cachedUrl)
        return true
    }
    
    private func loadImgFromURL() {
        guard let imageUrl = imageUrl else { return }
        let task = URLSession.shared.dataTask(with: URL(string: imageUrl)!, completionHandler: getImageFromResponse(data:response:error:))
        task.resume()
    }
    
    private func getImageFromResponse(data: Data?, response: URLResponse?, error: Error?) {
        guard error == nil else {
            print(error!)
            return
        }
        guard let data = data else {
            print("Data not found")
            return
        }
        
        
        guard let temp = UIImage(data: data) else {
            return
        }
        
        let avgColor = temp.averageColor ?? UIColor.clear
        
        DispatchQueue.main.async {
            self.image = temp
            self.averageColor = Color(avgColor)
            self.imageCache.set(image: temp, color: avgColor, forKey: self.imageUrl!)
        }
        
    }
    
}

class ImageCache {
    private var imgCache = NSCache<NSString, UIImage>()
    private var colorCache = NSCache<NSString, UIColor>()
    
    func getImage(forKey: String) -> UIImage? {
        let key = NSString(string: forKey)
        return imgCache.object(forKey: key)
    }
    
    func getColor(forKey: String) -> UIColor? {
        let key = NSString(string: forKey)
        return colorCache.object(forKey: key)
    }
    
    func set(image: UIImage, color: UIColor, forKey: String) {
        let key = NSString(string: forKey)
        imgCache.setObject(image, forKey: key)
        colorCache.setObject(color, forKey: key)
    }
    
    private static var imageCache = ImageCache()
    
    static func getImageCache() -> ImageCache {
        return imageCache
    }
    
}
