//
//  NetworkTester.swift
//  TuneWave Watch App
//
//  Created by Yukun Li on 2024/7/23.
//

import SwiftUI

actor NetworkToolKit {
    //用百度.com来测试网络连接，如果有网则返回true
    func testNetworkConnectivityWithMinimalBandwidth() async -> Bool {
        guard let url = URL(string: "https://www.baidu.com") else {
            return false
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        
        do {
            let (_, response) = try await URLSession.tolerantSession().data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                return true
            } else {
                return false
            }
        } catch {
            return false
        }
    }
}
extension URLSession {
    /// 创建一个配置为最宽容网络设置的`URLSession`
    static func tolerantSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        
        // 允许蜂窝网络访问
        configuration.allowsCellularAccess = true
        
        // 允许在昂贵网络下使用
        configuration.allowsExpensiveNetworkAccess = true
        configuration.allowsConstrainedNetworkAccess = true
        return URLSession(configuration: configuration)
    }
}
