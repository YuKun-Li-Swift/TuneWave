//
//  URLRequestExtension.swift
//  TuneWave Watch App
//
//  Created by Yukun Li on 2024/7/11.
//

import Foundation

extension URLRequest {
    enum URLRequestError: Error {
        case invalidURL
        case failedToCreateURL
    }
}

extension URLRequest.URLRequestError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return NSLocalizedString("无效的URL", comment: "Invalid URL")
        case .failedToCreateURL:
            return NSLocalizedString("无法创建URL", comment: "Failed to create URL")
        }
    }
    
    var failureReason: String? {
        switch self {
        case .invalidURL:
            return NSLocalizedString("提供的URL无效，无法解析", comment: "The provided URL is invalid and cannot be parsed")
        case .failedToCreateURL:
            return NSLocalizedString("无法根据提供的参数生成有效的URL", comment: "Failed to generate a valid URL with the given parameters")
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .invalidURL:
            return NSLocalizedString("请检查URL是否正确", comment: "Please check if the URL is correct")
        case .failedToCreateURL:
            return NSLocalizedString("请检查参数是否正确", comment: "Please check if the parameters are correct")
        }
    }
}

extension URLRequest {
    static func create(_ fullURL: String, parameters: [String: String], cachePolicy: URLRequest.CachePolicy) throws -> URLRequest {
        // 将参数编码为 URL 查询字符串
        guard var urlComponents = URLComponents(string: fullURL) else {
            throw URLRequestError.invalidURL
        }

        urlComponents.queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
        
        // 检查 URLComponents 是否成功生成 URL
        guard let url = urlComponents.url else {
            throw URLRequestError.failedToCreateURL
        }

        // 创建 URLRequest 并设置缓存策略
        var request = URLRequest(url: url)
        request.cachePolicy = cachePolicy

        return request
    }
}

private func example() {
    // 示例用法
    let playlistID = "12345"
    let useCache = true

    do {
        let request = try URLRequest.create("https://example.com/api/playlist", parameters: ["id": playlistID], cachePolicy: useCache ? .returnCacheDataElseLoad : .reloadIgnoringLocalAndRemoteCacheData)
        print(request)
    } catch {
        print("创建 URLRequest 失败: \(error.localizedDescription)")
        if let error = error as? LocalizedError {
            if let reason = error.failureReason {
                print("失败原因: \(reason)")
            }
            if let suggestion = error.recoverySuggestion {
                print("建议: \(suggestion)")
            }
        }
    }
}
