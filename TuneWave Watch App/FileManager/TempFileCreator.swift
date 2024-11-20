//
//  TempDataToURL.swift
//  TuneWave Watch App
//
//  Created by Yukun Li on 2024/7/15.
//

import Foundation
import SwiftUI

// 创建一个扩展来为Data生成临时URL
extension Data {
    func createTemporaryURL(`extension`: String?) throws -> URL {
        let fileURL = URL.createTemporaryURL(extension: `extension`)
        // 将Data写入文件
        try self.write(to: fileURL)
        return fileURL
    }
    func createTemporaryURLAsync(`extension`: String?) async throws -> URL {
        return try await AsyncWriter.createTemporaryURL(data:self,extension: `extension`)
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

actor AsyncWriter {
    static
    func createTemporaryURL(data:Data,`extension`: String?) async throws -> URL {
        let fileURL = URL.createTemporaryURL(extension: `extension`)
        // 将Data写入文件
        try data.write(to: fileURL)
        return fileURL
    }
}

extension URL {
    static
    func createTemporaryURL(`extension`: String? = nil) -> URL {
        // 获取临时目录
        let temporaryDirectoryURL = FileManager.default.temporaryDirectory
        
        // 创建唯一文件名
        let uniqueFilename = {
            if let `extension` {
                UUID().uuidString + "." + `extension`
            } else {
                UUID().uuidString
            }
        }()
        
        // 生成文件URL
        let fileURL = temporaryDirectoryURL.appendingPathComponent(uniqueFilename)
        return fileURL
    }
}

struct TempFileCreator {
    static
    func clearTemporaryDirectory() {
        let fileManager = FileManager.default
        let tempDirectory = fileManager.temporaryDirectory

        do {
            let tempFiles = try fileManager.contentsOfDirectory(atPath: tempDirectory.path)
            
            for file in tempFiles {
                let filePath = tempDirectory.appendingPathComponent(file).path
                try fileManager.removeItem(atPath: filePath)
            }
            
            print("Temporary directory cleared successfully.")
        } catch {
            print("Error clearing temporary directory: \(error.localizedDescription)")
        }
    }
}
