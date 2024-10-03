//
//  MusicModel.swift
//  TuneWave Watch App
//
//  Created by Yukun Li on 2024/7/9.
//

import SwiftUI

//目的只有一个：在线只是幌子，其实一切逻辑按照本地对待，没有OTA下载歌词、没有OTA加载封面图、没有OTA播放歌曲，就Watch这一切后台就没有网、前台网速也不快的场景，不做这个哈！
//但是
class MusicModel {
    //需要登录
    func loadAMusic(muicID:String,user:YiUserContainer) throws -> YiMusic {
        //download mp3
        throw MusicLoadError.notDev
    }
    enum MusicLoadError:Error,LocalizedError {
    case notDev
        var errorDescription: String? {
            switch self {
            case .notDev:
                "该功能尚未完成开发"
            }
        }
    }
    func downloadAMusic(musicID:String,user:YiUserContainer,modelContext:ModelContext) throws -> YiMusic {
        //需要登录
        //下载mp3和缓存图片
        throw MusicLoadError.notDev
    }
    
    enum PlayListPlayOption {
        case prefix10
        case random10
        case suffix10
    }
    //在线播放用最低质量的图片和音频质量。设置中允许高质量，因为Watch 4G网络也不慢啊。
    func playPlaylist(option:PlayListPlayOption) -> [YiMusic] {
        return []
    }

    enum PlayListDownloadOption {
        case prefix50
        case random50
        case suffix50
    }
    //进入多选模式后，歌单上直接标记了哪几首歌是已经下载了。多选模式按钮旁边还有一个一键下载按钮，可以选择“随机下载10首尚未下载的歌曲”、“下载前10首未下载过的歌曲”、“下载后10首未下载过的歌曲”。
    func downloadPlaylist(option:PlayListDownloadOption) -> [YiMusic] {
        return []
    }
}

import SwiftData

@Model
class YiMusic:Identifiable,Hashable,Equatable {
    var id = UUID()
    var isOnline:Bool
    var musicID:String
    var name:String
    //想获取专辑信息？联网显示！
    var artist:String
    
    
    //注意检查isEmpty来代表有没有歌词
    var lyric:String
    var tlyric:String

    
    @Attribute(.externalStorage)
    var albumImg:Data
    @Attribute(.externalStorage)
    var audioData:Data
    var audioDataFidelity:String
    var audioDataFileExtension:String

    init(id: UUID = UUID(), isOnline: Bool, musicID: String, name: String, artist: String, lyrics: String,tlyric:String, albumImg: Data, audioData: Data, audioDataFidelity: String,audioDataFileExtension:String) {
        self.id = id
        self.isOnline = isOnline
        self.musicID = musicID
        self.name = name
        self.artist = artist
        self.lyric = lyrics
        self.tlyric = tlyric
        self.albumImg = albumImg
        self.audioData = audioData
        self.audioDataFidelity = audioDataFidelity
        self.audioDataFileExtension = audioDataFileExtension
    }
    
    func toShell() -> YiMusicShell {
        .init(musicID: musicID)
    }
    
    func toFullShell() async throws -> YiMusicDetailedShell {
        let url = try await self.albumImg.createTemporaryURLAsync(extension: "")
        return .init(id: id, musicID: musicID, name: name, albumImgURL: url,plainShell:toShell())
    }
}

///如果直接在内存中存储整个来自数据库的列表，因为每个Record是包含了实际的Data的，会占用超大量内存引起闪退
struct YiMusicShell:Identifiable,Equatable {
    var id:String {
        musicID
    }
    var musicID:String
}

struct YiMusicDetailedShell:Identifiable,Equatable,Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    var id:UUID
    var musicID:String
    var name:String
    var albumImgURL:URL
    var plainShell:YiMusicShell
}


enum GetCachedMusicError:Error,LocalizedError {
    case musicLost
    var errorDescription: String? {
        switch self {
        case .musicLost:
            "音乐丢失了，"+DeveloperContactGenerator.generate()
        }
    }
}
