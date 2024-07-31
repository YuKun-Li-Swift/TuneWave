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
//步骤1必须在步骤4前，其余步骤可以并行化
actor MusicLoader {
    var isOnline:Bool
    var musicID: String
    var name: String
    var artist: String
    var coverImgURL: URL
    var vm:MusicLoadingViewModel
    var user: YiUserContainer
    //这里要求YiUserContainer是为了提醒开发人员，登录后才能播放音乐。因为不登录的话还要处理试听版的问题。
    //即使是登录后也要处理会员状态变化，之前缓存的音乐现在是不是应该重新下载（以更高音质/非试听版）。
    init(isOnline:Bool,musicID: String, name: String, artist: String, coverImgURL: URL,vm:MusicLoadingViewModel, user: YiUserContainer) {
        self.isOnline = isOnline
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
        let json = try await AF.request(fullURL,parameters: {
            if isOnline {
                ["id":musicID,"br":"64000"] as [String:String]//在线播放用64k音质，加载速度很重要
            } else {
                ["id":musicID,"br":"320000"] as [String:String]//下载的话用320k音质
            }
        }()).LSAsyncJSON()
        try json.errorCheck()
        print("请求到音乐链接\(json)")
        //可能是只能听试听版（那不播放了，不然之后开了VIP还要重新缓存音乐）
        //也可能是完全听不了，比如专辑是付费专辑
        if let code:Int64? = json["data"].array?.first?["code"].int64 {
            switch code {
             case -110:
                 throw Step1Error.noPaidAlbum
             case 200:
                if let cantNormallyListen = json["data"].array?.first?["freeTrialPrivilege"]["cannotListenReason"].int64 {
                    //如果这个字段不是null，就说明有问题了
                    switch cantNormallyListen {
                        case 1:
                        //只能听试听版导致的播放异常
                         throw Step1Error.noVIP
                    default:
                        //可能是IP不对，比如海外无法听大陆的音乐
                        throw Step1Error.cannotListen
                    }
                } else {
                    //这是一切正常的情况
                }
            case 404:
                throw Step1Error.noMusicSource
             default:
                //可能是IP不对，比如海外无法听大陆的音乐
                throw Step1Error.cannotListen
           }
        }

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
        case noVIP
        case noMusicSource
        case noPaidAlbum
        case cannotListen
        var errorDescription: String? {
            switch self {
            case .noMusicSource:
                "这首音乐在网易云音乐没有音源，您可以在网易云音乐手机端检查该音乐能否正常播放"
            case .cannotListen:
                "目前无法播放这首音乐，" + DeveloperContactGenerator.generate()
            case .noPaidAlbum:
                "您的网易云账号没有权限听这首音乐（没有购买该音乐所属的数字专辑）"
            case .noVIP:
                "您的网易云账号没有权限听这首音乐（没有网易云黑胶会员）"
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
    func step2() async throws {
        let (cover,_) = try await URLSession.shared.data(from: {
            if isOnline {
                coverImgURL.lowRes(xy2x: 172*3)//在线播放用小图。为什么选择这个尺寸？因为41mm的NowPlay的大封面图是这个尺寸
            } else {
                coverImgURL
            }
        }())
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
            //永远不要超时，因为音乐云盘里的音乐会很大
            AF.download(URLRequest(url: audioURL,timeoutInterval: 3600), to: destination)
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

