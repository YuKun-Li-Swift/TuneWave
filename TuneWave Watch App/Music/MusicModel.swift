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

//APP的内存水位上限是300MB，所以我们不能直接访问数据库里的所有对象（一起访问），因为会在瞬时占用大量的内存
@MainActor//因为ModelContext不是可发送的
struct PersistentModel {
    
    static
    func fetchFromDBVersionA(predicate:Predicate<YiMusic>,modelContext:ModelContext) async throws -> [YiMusicDetailedShell] {
        
        var descriptor = FetchDescriptor<YiMusic>(predicate: predicate)
        descriptor.includePendingChanges = false//1️⃣使用batchSize参数，确保是懒加载
        let allSongID = try modelContext.fetch(descriptor,batchSize: 2).map { music in
            music.musicID
        }
        var cachedMusic = [YiMusicDetailedShell]()
        
        for songID in allSongID {
            if let music = try modelContext.fetch(.init(predicate: #Predicate<YiMusic> { music in
                music.musicID == songID
            })).first {
                cachedMusic.append(try await music.toDetailedShell())//在循环中一首一首歌操作，避免大量的内存占用
            } else {
                //不应该出现这个
                throw GetCachedMusicError.musicLost
            }
        }
        
        return cachedMusic
    }
    
    static
    func fetchFromDBVersionB(predicate:Predicate<YiMusic>,modelContext:ModelContext) async throws -> [YiMusicDetailedShell] {
        
        var descriptor = FetchDescriptor<YiMusic>(predicate: predicate)
        let allRecordID = try modelContext.fetchIdentifiers(descriptor)//2️⃣只取Identifiers，避免大量占用内存
        var cachedMusic = [YiMusicDetailedShell]()
        
        for recordID in allRecordID {
            //在循环中一首一首歌操作，避免并行访问的大量内存占用
            if let music = try modelContext.fetch(.init(predicate: #Predicate<YiMusic> { music in
                music.persistentModelID == recordID
            })).first {
                cachedMusic.append(try await music.toDetailedShell())
            } else {
                //不应该出现这个
                throw GetCachedMusicError.musicLost
            }
        }
        
        
        return cachedMusic
    }
    
    static
    func fetchFromDBVersionC(predicate:Predicate<YiMusic>,sortBy:(YiMusicDetailedShell,YiMusicDetailedShell) -> Bool,modelContext:ModelContext) async throws -> [YiMusicDetailedShell] {
        var descriptor = FetchDescriptor<YiMusic>(predicate: predicate)
        let allRecordID = try modelContext.fetchIdentifiers(descriptor)
        //允许每次并行操作3首歌，比for in一首一首处理更快
        let cachedMusic = try await concurrentConvert(source: allRecordID, maxConcurrency: 3) { recordID in
            //在循环中一首一首歌操作，避免并行访问的大量内存占用
            if let music = try modelContext.fetch(.init(predicate: #Predicate<YiMusic> { music in
                music.persistentModelID == recordID
            })).first {
                return (try await music.toDetailedShell())
            } else {
                //不应该出现这个
                throw GetCachedMusicError.musicLost
            }
        }.sorted(by: sortBy)
        return cachedMusic
    }

    ///是一个限制了同一时间可以运行的任务个数的TaskGroup
    fileprivate
    static
    func concurrentConvert<S: Sequence, T, U>(
        source: S,
        maxConcurrency: Int = 3,
        conversion: @escaping (T) async throws -> U
    ) async throws -> [U] where S.Element == T {
        
        let sourceArray = Array(source)
        
        return try await withThrowingTaskGroup(of: (Int, U).self) { group in
            var results: [(Int, U)] = []
            results.reserveCapacity(sourceArray.count)
            
            var index = 0
            
            func addNextTask() {
                guard index < sourceArray.count else { return }
                let currentIndex = index
                group.addTask {
                    let convertedItem = try await conversion(sourceArray[currentIndex])
                    return (currentIndex, convertedItem)
                }
                index += 1
            }
            
            // 初始添加最大并发数的任务
            for _ in 0..<min(maxConcurrency, sourceArray.count) {
                addNextTask()
            }
            
            // 处理结果并动态添加新任务
            while let result = try await group.next() {
                results.append(result)
                if index < sourceArray.count {
                    addNextTask()
                }
            }
            
            // 按原始顺序排序结果
            return results.sorted { $0.0 < $1.0 }.map { $0.1 }
        }
    }
}

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
    
    func toDetailedShell() async throws -> YiMusicDetailedShell {
        let url = try await self.albumImg.createTemporaryURLAsync(extension: nil)
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
    @MainActor
    func toAliveMusic(playerHolder:MusicPlayerHolder) throws -> YiMusic {
        try playerHolder.musicShellToRealObject(self)
    }
    //targetOrder是目标的musicID顺序
    static
    func sortTo(existMusics:[YiMusicDetailedShell],targetOrder:[String]) -> [YiMusicDetailedShell] {
        var sortedMusics:[YiMusicDetailedShell] = []
        for songID in targetOrder {
            if let cachedSong = existMusics.first(where: { cachedSong in
                cachedSong.musicID == songID
            }) {
                sortedMusics.append(cachedSong)
            } else {
                //这首歌并没有被本地缓存，跳过就行
            }
        }
        return sortedMusics
    }
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
