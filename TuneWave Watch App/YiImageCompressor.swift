//
//  YiImageCompressor.swift
//  TuneWave Watch App
//
//  Created by Yukun Li on 2024/7/15.
//

import Foundation

extension URL {
    ///请提供预计显示分辨率的两倍数值，来确保显示清晰
    func lowRes(xy2x:Int) -> URL {
        if let newURL = self.addQueryParameter(name: "param", value: "\(xy2x)y\(xy2x)") {
            return newURL
        } else {
            print("URL无法正常解析，请检查：\(self)")
            return self
        }
    }
    
    func addQueryParameter(name: String, value: String) -> URL? {
        let url = self
        guard var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        
        var queryItems = urlComponents.queryItems ?? []
        let queryItem = URLQueryItem(name: name, value: value)
        queryItems.append(queryItem)
        urlComponents.queryItems = queryItems
        
        return urlComponents.url
    }

}
