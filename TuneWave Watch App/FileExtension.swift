//
//  File Extension.swift
//  TuneWave
//
//  Created by Yukun Li on 2024/8/25.
//

import Foundation

//因为App现在支持锁屏后继续下载，但是锁屏后手表会进入文件保护模式，此时虽然网络连接是正常的，但是无法读写文件。需要预先把下载后可能读取的文件在这里设置好允许操作。如果下载失败，这里创建出的文件应当自动删除，所以请使用临时文件夹的URL传入
///请在确定屏幕点亮的时候调用我
func setAllowAccessOnLock(for url: URL) throws {
    let fileManager = FileManager.default
    
    // 如果文件不存在，创建一个空文件
    if !fileManager.fileExists(atPath: url.path) {
        // 创建文件并设置默认内容为空
        fileManager.createFile(atPath: url.path, contents: nil, attributes: nil)
    }
    
    // 设置文件的保护级别为NSFileProtectionNone
    do {
        try fileManager.setAttributes([.protectionKey: FileProtectionType.none], ofItemAtPath: url.path)
    } catch {
        throw NSError(domain: "SetFileProtectionError", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to set file protection level: \(error.localizedDescription)"])
    }
}
