//
//  StorageStatistics.swift
//  TuneWave
//
//  Created by Yukun Li on 2025/2/18.
//

import SwiftData
import SwiftUI
import os
import SDWebImage

fileprivate
extension ModelContext {
    // 包含数据库本身的.store文件和使用.externalStorage存储的Data
    var dbFolderURL: URL? {
        if let storeFileURL = container.configurations.first?.url {
            return removeLastPathComponent(from: storeFileURL)
        } else {
            return nil
        }
    }
}

fileprivate
func removeLastPathComponent(from url: URL) -> URL? {
    
    // 获取 URL 的路径组件
    var pathComponents = url.pathComponents
    
    // 如果路径组件为空，返回 nil
    if pathComponents.isEmpty {
        return nil
    }
    
    // 移除最后一个路径组件
    pathComponents.removeLast()
    
    // 重新构建 URL
    var newURL = url
    newURL.deleteLastPathComponent()
    
    // 返回新的 URL 字符串
    return newURL
}

fileprivate
func calculateSDWebImageCacheSize() async -> (fileCount: Int, totalSize: Int) {
    let (fileCount, totalSize) = await SDImageCache.shared.calculateSize()
    return (Int(fileCount), Int(totalSize))
}

fileprivate
func getURLCacheSize() -> Int {
    URLCache.shared.currentDiskUsage
}

struct DBSpaceAnalyzer: View {
    @Environment(\.modelContext)
    private var modelContext
    @State private var folderURL: URL?
    @State private var dbSize: String = ""
    @State private var imageCacheSize: String = ""
    @State private var urlCacheSize: String = ""
    @State private var errorMessage: String = ""
    
    var body: some View {
        List {
            if !errorMessage.isEmpty {
                Text("错误: \(errorMessage)")
                    .foregroundColor(.red)
            }
            VStack(alignment: .leading) {
                // 因为歌单的缓存存粹基于CachebleAlamofire做的
                Text("歌单列表已占空间")
                Text(urlCacheSize)
                    .foregroundStyle(.secondary)
                    .font(.footnote)
            }
            VStack(alignment: .leading) {
                // 数据库的空间主要是使用.externalStorage存储的音频文件和封面文件
                Text("音乐数据已占空间")
                Text(dbSize)
                    .foregroundStyle(.secondary)
                    .font(.footnote)
            }
            VStack(alignment: .leading) {
                // 图片缓存应该不会占太多空间，这个值放在这儿只是给用户看看的
                Text("图片缓存已占空间")
                Text(imageCacheSize)
                    .foregroundStyle(.secondary)
                    .font(.footnote)
            }
        }
        .animation(.smooth, value: dbSize)
        .animation(.smooth, value: imageCacheSize)
        .animation(.smooth, value: urlCacheSize)
        .animation(.smooth, value: errorMessage)
        .navigationTitle("空间占用统计")
        .onLoad {
            if let url = modelContext.dbFolderURL {
                os_log("文件夹URL：\(url.absoluteString)")
                folderURL = url
                calculateFolderSize(url: url)
                calculateImageCacheSize()
                calculateURLCacheSize()
            } else {
                errorMessage = "无法计算空间占用，请联系开发者。"
            }
        }
    }
    
    private func calculateFolderSize(url: URL) {
        do {
            // 递归计算文件夹大小
            let totalSize = try calculateSizeRecursively(at: url)
            
            // 格式化文件大小
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
            formatter.countStyle = .file
            dbSize = formatter.string(fromByteCount: totalSize)
            errorMessage = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func calculateSizeRecursively(at url: URL) throws -> Int64 {
        // 不能.skipsHiddenFiles，因为使用.externalStorage存储的Data是隐藏文件。
        let options: FileManager.DirectoryEnumerationOptions = [.skipsPackageDescendants]
        let contents = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey], options: options)
        var totalSize: Int64 = 0
        
        for item in contents {
            let resources = try item.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])
            
            // 如果是文件夹，递归计算大小
            if resources.isDirectory == true {
                totalSize += try calculateSizeRecursively(at: item)
            } else if let fileSizeInBytes = resources.fileSize {
                // 如果是文件，累加文件大小
                totalSize += Int64(fileSizeInBytes)
            }
        }
        
        return totalSize
    }
    
    private func calculateImageCacheSize() {
        Task {
            let (_, totalSize) = await calculateSDWebImageCacheSize()
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
            formatter.countStyle = .file
            imageCacheSize = formatter.string(fromByteCount: Int64(totalSize))
        }
    }
    
    private func calculateURLCacheSize() {
        let totalSize = getURLCacheSize()
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        urlCacheSize = formatter.string(fromByteCount: Int64(totalSize))
    }
}
