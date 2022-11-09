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
//        print(output)
        guard let response = output.response as? HTTPURLResponse else { throw URLError(.badServerResponse)
        }
        
        if response.statusCode == 401 {
            throw URLError(.userAuthenticationRequired)
        }
        
        if response.statusCode < 200 || response.statusCode >= 300 {
            throw URLError(.badServerResponse)
        }
        
//        do {
//            let json = try JSONSerialization.jsonObject(with: output.data, options: [.fragmentsAllowed]) as? [String : Any]
//            print(json)
//        } catch ( let err){
//            print("errorMsg: \(err)")
//        }
        
        return output.data
    }
    
    static func handleCompletion(completion: Subscribers.Completion<Error>) {
        switch completion {
        case .finished:
            break
        case .failure(let e):
            print("Function: \(#function), line: \(#line),", e)
        }
    }
    
    static func getAsHttpBody(body: Dictionary<String, String>) -> Data? {
        var dataString = ""
        for (k, v) in body {
            dataString.append(k)
            dataString.append("=")
            dataString.append(v)
            dataString.append("&")
        }
        
        dataString = String(dataString[..<dataString.index(dataString.startIndex, offsetBy: dataString.count - 1)])
        return dataString.data(using: String.Encoding.ascii, allowLossyConversion: true)
    }
    
}
