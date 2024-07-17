//
//  TempDataToURL.swift
//  TuneWave Watch App
//
//  Created by Yukun Li on 2024/7/15.
//

import Foundation

// 创建一个扩展来为Data生成临时URL
extension Data {
    func createTemporaryURL(`extension`: String) throws -> URL {
        let fileURL = URL.createTemporaryURL(extension: `extension`)
        // 将Data写入文件
        try self.write(to: fileURL)
        return fileURL
    }
//    func createTemporaryURL(filename: String) throws -> URL {
//        // 获取临时目录
//        let temporaryDirectoryURL = FileManager.default.temporaryDirectory
//        
//        // 创建唯一文件名
//        let uniqueFilename = UUID().uuidString + "-" + filename
//        
//        // 生成文件URL
//        let fileURL = temporaryDirectoryURL.appendingPathComponent(uniqueFilename)
//        // 将Data写入文件
//        try self.write(to: fileURL)
//        return fileURL
//    }
}

extension URL {
    static
    func createTemporaryURL(`extension`: String) -> URL {
        // 获取临时目录
        let temporaryDirectoryURL = FileManager.default.temporaryDirectory
        
        // 创建唯一文件名
        let uniqueFilename = UUID().uuidString + "." + `extension`
        
        // 生成文件URL
        let fileURL = temporaryDirectoryURL.appendingPathComponent(uniqueFilename)
        return fileURL
    }
}
