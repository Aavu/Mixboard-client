//
//  NetworkManager.swift
//  Mixboard
//
//  Created by Raghavasimhan Sankaranarayanan on 11/1/22.
//

import Foundation
import Combine

// Inspired from: https://www.youtube.com/watch?v=pp5-ASYnY0o
class NetworkManager {
    
    enum RequestType: String {
        case POST
        case GET
    }
    
    struct Header {
        let value: String
        let key: String
    }
    
    enum ContentType: String {
        case JSON = "Application/json"
        case FORM = "Application/x-www-form-urlencoded"
    }
    
    static func request(url: URL, type: RequestType, httpbody: Data? = nil, contentType: ContentType = .JSON, headers: [Header]? = nil) -> AnyPublisher<Data, Error> {
        var request = URLRequest(url: url)
        request.httpMethod = type.rawValue
        request.setValue(contentType.rawValue, forHTTPHeaderField: "Content-Type")
        
        if let headers = headers {
            for header in headers {
                request.addValue(header.value, forHTTPHeaderField: header.key)
            }
        }
        request.httpBody = httpbody
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .subscribe(on: DispatchQueue.global(qos: .default))
            .tryMap({try handleURLResponse(output: $0)})
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    static func handleURLResponse(output: URLSession.DataTaskPublisher.Output) throws -> Data {
        guard let response = output.response as? HTTPURLResponse,
              response.statusCode >= 200 && response.statusCode < 300 else {
            throw URLError(.badServerResponse)
        }
        
        return output.data
    }
    
    static func handleCompletion(completion: Subscribers.Completion<Error>) {
        switch completion {
        case .finished:
            break
        case .failure(let e):
            print("completion failed: \(e)")
        }
    }
    
}
