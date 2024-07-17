//
//  AlaCache.swift
//  TuneWave Watch App
//
//  Created by Yukun Li on 2024/7/15.
//

import Foundation
import Alamofire

class AlaCache {
    static
    func createCachebleAlamofire(diskPath: String) -> Session {
        // 创建一个URLCache实例
        let memoryCapacity = 50 * 1024 * 1024 // 50 MB 内存缓存
        let diskCapacity = 100 * 1024 * 1024  // 100 MB 磁盘缓存
        let cache = URLCache(memoryCapacity: memoryCapacity, diskCapacity: diskCapacity, diskPath: "myCachePath")

        // 创建一个自定义的URLSessionConfiguration
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = cache
        configuration.requestCachePolicy = .useProtocolCachePolicy
        return Session(configuration: configuration)
    }
}
