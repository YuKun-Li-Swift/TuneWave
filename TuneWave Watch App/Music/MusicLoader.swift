//
//  MusicLoader.swift
//  TuneWave Watch App
//
//  Created by Yukun Li on 2024/7/15.
//

import Foundation
import SwiftData
import Alamofire

//这个类负责加载已经缓存的音乐、负责请求音乐链接（step1）、负责下载封面图（step2）、负责下载歌词（step3）、负责下载音乐文件并且实时追踪进度（step4）
actor MusicLoader {
    var musicID: String
    var name: String
    var artist: String
    var coverImgURL: URL
    var vm:MusicLoadingViewModel
    var user: YiUserContainer
    //这里要求YiUserContainer是为了提醒开发人员，登录后才能播放音乐。因为不登录的话还要处理试听版的问题。
    //即使是登录后也要处理会员状态变化，之前缓存的音乐现在是不是应该重新下载（以更高音质/非试听版）。
    init(musicID: String, name: String, artist: String, coverImgURL: URL,vm:MusicLoadingViewModel, user: YiUserContainer) {
        self.musicID = musicID
        self.name = name
        self.artist = artist
        self.coverImgURL = coverImgURL
        self.vm = vm
        self.user = user
    }
    @MainActor
    func getCachedMusic(modelContext: ModelContext) async throws -> YiMusic? {
        let musicIDCopy = await musicID
        let predicate = #Predicate<YiMusic> { music in
            music.musicID == musicIDCopy
        }
        let fetchDescriptor = FetchDescriptor<YiMusic>(predicate: predicate)
        let allResult = try modelContext.fetch(fetchDescriptor)
        if let matched = allResult.last {
            return matched
        } else {
            return nil
        }
    }
    
    var audioURL:URL? = nil
    var audioDataFidelity:String? = nil
    var audioFileExtension:String? = nil
    //如果要 320k 则可设置为 320000
    //考虑到Apple Watch通过手机蓝牙共享网络网速慢、使用本app的时候还可能连耳机、进一步挤占蓝牙带宽，故默认音质为64k
    func step1() async throws {
        let route = "/song/url"
        let fullURL = baseAPI + route
        let json = try await AF.request(fullURL,parameters: ["id":musicID,"br":"64000"] as [String:String]).LSAsyncJSON()
        try json.errorCheck()
        print("请求到音乐链接\(json)")
        guard let link = json["data"].array?.first?["url"].url else {
            throw Step1Error.noLink
        }
        guard let size = json["data"].array?.first?["size"].int64 else {
            throw Step1Error.noSize
        }
        //已知取值：m4a
        guard let type = json["data"].array?.first?["type"].string else {
            throw Step1Error.noFileExtension
        }
        //已知取值：standard
        guard let level = json["data"].array?.first?["level"].string else {
            throw Step1Error.noFileExtension
        }
        self.audioURL = link
        self.audioFileExtension = type
        self.audioDataFidelity = level
        await MainActor.run { @MainActor [vm] in
            vm.audioDataSize = Double(size)
        }
    }
    enum Step1Error:Error,LocalizedError {
        case noLink
        case noSize
        case noFileExtension
        case noLevel
        var errorDescription: String? {
            switch self {
            case .noLink:
                "找不到音乐的播放链接"
            case .noSize:
                "找不到音乐占的空间大小"
            case .noFileExtension:
                "找不到音乐的文件扩展名"
            case .noLevel:
                "找不到音质说明"
            }
        }
    }
    var coverData:Data? = nil
    func step2() throws {
        let cover = try Data(contentsOf: coverImgURL)
        self.coverData = cover
    }
    
    //nil代表没请求上，空字符串代表这首歌没有歌词
    var lyrics:String? = nil
    var tlyric:String? = nil
    func step3() async throws {
        let route = "/lyric"
        let fullURL = baseAPI + route
        let json = try await AF.request(fullURL,parameters: ["id":musicID] as [String:String]).LSAsyncJSON()
        try json.errorCheck()
        print("歌词\(json)")
        if let lrc = json["lrc"]["lyric"].string {
            self.lyrics = lrc
        } else {
            print("遇到一首\(musicID)的没有歌词的歌\(json)")
            self.lyrics = ""
        }
        if let lrc = json["tlyric"]["lyric"].string {
            self.tlyric = lrc
        } else {
            print("遇到一首\(musicID)的没有歌词的歌\(json)")
            self.tlyric = ""
        }
    }
    enum Step3Error:Error,LocalizedError {
        case noLyric
        var errorDescription: String? {
            switch self {
            case .noLyric:
                "找不到歌词"
            }
        }
    }
    
    var audioData:Data? = nil
    func step4() async throws {
        guard let audioURL,let audioFileExtension else {
            throw NeverError.neverError
        }
        // 定义下载文件保存的路径
        let destination: DownloadRequest.Destination = { _, _ in
            let fileURL = URL.createTemporaryURL(extension: audioFileExtension)
            return (fileURL, [.removePreviousFile, .createIntermediateDirectories])
        }
        try await withCheckedThrowingContinuation { (continuation:CheckedContinuation<Void,Error>) -> Void in
            AF.download(audioURL, to: destination)
                    .downloadProgress { progress in
                        Task { @MainActor in
                            await self.vm.audioDownloadProgress = progress.fractionCompleted
                        }
                    }
                    .response { response in
                        do {
                            // 下载完成后的处理
                            if response.error == nil, let filePath = response.fileURL {
                                self.audioData = try Data(contentsOf: filePath)
                            } else {
                                throw response.error ?? Step4Error.unknowNetError
                            }
                            continuation.resume(returning: ())
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
        }
    }
    enum Step4Error:Error,LocalizedError {
        case unknowNetError
        var errorDescription: String? {
            switch self {
            case .unknowNetError:
                "未知网络错误"
            }
        }
    }
    
    func generateFinalMusicObject() throws -> YiMusic {
        guard let lyrics,let tlyric else {
            throw GenerateFinalMusicObjectError.parametersNotReady
        }
        guard let coverData else {
            throw GenerateFinalMusicObjectError.parametersNotReady
        }
        guard let audioData else {
            throw GenerateFinalMusicObjectError.parametersNotReady
        }
        guard let audioDataFidelity else {
            throw GenerateFinalMusicObjectError.parametersNotReady
        }
        guard let audioFileExtension else {
            throw GenerateFinalMusicObjectError.parametersNotReady
        }
        let object = YiMusic(isOnline: true, musicID: self.musicID, name: self.name, artist: self.artist, lyrics: lyrics, tlyric: tlyric, albumImg: coverData, audioData: audioData, audioDataFidelity: audioDataFidelity, audioDataFileExtension: audioFileExtension)
        return object
    }
    enum GenerateFinalMusicObjectError:Error,LocalizedError {
        case parametersNotReady
        var errorDescription: String? {
            switch self {
            case .parametersNotReady:
                "参数尚未准备完全"
            }
        }
    }
}

