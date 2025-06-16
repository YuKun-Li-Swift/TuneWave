//
//  DebugTool.swift
//  TuneWave
//
//  Created by Yukun Li on 2025/4/12.
//

import Foundation

func humanReadableFileSize(url: URL) -> String {
    do {
        // 获取文件属性
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        
        // 从属性中获取文件大小
        if let fileSize = attributes[.size] as? Int64 {
            return formatFileSize(size: fileSize)
        } else {
            return "未知大小"
        }
    } catch {
        return "错误: \(error.localizedDescription)"
    }
}

func formatFileSize(size: Int64) -> String {
    let byteCountFormatter = ByteCountFormatter()
    byteCountFormatter.allowedUnits = [.useAll]
    byteCountFormatter.countStyle = .file
    byteCountFormatter.includesUnit = true
    byteCountFormatter.includesCount = true
    
    return byteCountFormatter.string(fromByteCount: size)
}

// 使用示例
fileprivate
func example() {
    // 假设我们有一个本地文件的URL
    if let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
        let fileURL = documentsURL.appendingPathComponent("example.pdf")
        
        // 获取并打印人类可读的文件大小
        let readableSize = humanReadableFileSize(url: fileURL)
        print("文件大小: \(readableSize)")
    }
}
