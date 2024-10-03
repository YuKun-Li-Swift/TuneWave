//
//  MusicPlayerHolder.swift
//  TuneWave Watch App
//
//  Created by Yukun Li on 2024/7/15.
//

import Foundation
import SwiftUI
import AVFoundation
import Combine
import MediaPlayer


//既然ContentView持有MusicPlayerHolder，那我就附加在ContentView上
struct SavePlayingModeChange: ViewModifier {
    @Environment(MusicPlayerHolder.self)
    var musicHolder
    func body(content: Content) -> some View {
        content
            .onChange(of: musicHolder.playingMode, initial: false) { oldValue, newValue in
                UserDefaults.standard.setValue(newValue.rawValue, forKey: "TuneWavePlayingMode")
            }
    }
}

@MainActor
@Observable
class MusicPlayerHolder {
    let avplayer = AVPlayer()
    var musicURL:URL? = nil
    //播放列表
    
    var playingList:[YiMusicShell] = []
    var currentMusic:YiMusic? = nil
    var cancellable:AnyCancellable?
    var lyricsCancellable:Any?
    
    var playingError:String = ""
    var waitingPlayingReason:String = ""
    var playingMode:PlayingMode = .singleLoop
    var switchMusicError:String? = nil
    var lyricsData:LyricsData?
    //已经播放过的音乐，低权重随机到这些
    var playedItems:[YiMusicShell] = []
    
    //因为切歌是有一个“歌词解析”的过程的，可能存在用户切了一首歌，在歌词解析完前切换了另一首歌，这是竞态，需要避免
    var switchMusicTask:Task<Void,Never>?
    
    let remoteCommandManager = RemoteCommandManager()
    
    init() {
        //每次变化了就由SavePlayingModeChange来保存
        if let hasRemember = UserDefaults.standard.value(forKey: "TuneWavePlayingMode") as? Int,let rememberMode = PlayingMode(rawValue: hasRemember) {
            self.playingMode = rememberMode
        } else {
            //没有记忆，默认使用单曲循环
        }
    }
    
    
    var musicShellToRealObject:(YiMusicShell) throws -> (YiMusic) = { _ in
        throw MusicShellToRealObjectError.notImplement
    }
    
    enum MusicShellToRealObjectError:Error,LocalizedError {
        case notImplement
        case musicLost
        var errorDescription: String? {
            switch self {
            case .notImplement:
                "该功能未实现"
            case .musicLost:
                "这首音乐丢失了"
            }
        }
    }
    
    //如果视频在播放，每帧触发一次
    func startToUpdateLyrics(onTimeUpdate:@escaping (CMTime)->()) {
        //先销毁先前的再设置新的，免得先前的内存泄露了
        stopUpdateLyrics()
        let interval = CMTime(seconds: 0.0167, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        lyricsCancellable = avplayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            onTimeUpdate(time)
        }
    }
    func stopUpdateLyrics() {
        if let timeObserverToken = lyricsCancellable {
            avplayer.removeTimeObserver(timeObserverToken)
            self.lyricsCancellable = nil
        }
    }
    enum PlayMusicError:Error,LocalizedError {
        case notRightPlayingList
        case failedToFetchMusicDuration
        var errorDescription: String? {
            switch self {
            case .failedToFetchMusicDuration:
                "音乐播放失败，因为无法获取音乐时长，"+DeveloperContactGenerator.generate()
            case .notRightPlayingList:
                "歌单出现异常，请换一个歌单播放"
            }
        }
    }
    //playingList是当前歌曲的上下文，目前的策略是，当前歌曲从哪一个歌单里来的，就把播放列表替换为那个歌单。
    //如果播放的这首歌已经被缓存了，那么playingList就会包含这首歌
    //如果播放的这首歌，在点击音乐Row时尚未被缓存，那么playingList就不包含这首歌
    ///修改此次逻辑时，记得考虑要不要修改switchMusic(to yiMusic:YiMusic)的逻辑
    func playMusic(_ yiMusic:YiMusic,playingList:[YiMusicShell],preferencedSeekModeRawValue: SeekPreference.RawValue) async throws {
        if !playingList.contains(yiMusic.toShell()) {
            throw PlayMusicError.notRightPlayingList
        }
        self.playingList = playingList
        self.currentMusic = yiMusic
        let url:URL = try yiMusic.audioData.createTemporaryURL(extension: yiMusic.audioDataFileExtension)
        print("音乐链接\(url)")
        self.musicURL = url
        let item = AVPlayerItem(url: url)
        avplayer.replaceCurrentItem(with: item)
        let duration = item.duration
        self.lyricsData = await .init(music: yiMusic, duration: duration)
        avplayer.audiovisualBackgroundPlaybackPolicy = .continuesIfPossible
        avplayer.actionAtItemEnd = .none
        configureRemoteCommandCenter(preferencedSeekModeRawValue: preferencedSeekModeRawValue)
        
        NowPlayHelper.updateNowPlayingInfoWith(yiMusic, playbackRate: 1.0)
        avplayer.defaultRate = 1.0
        avplayer.rate = 1.0
        avplayer.playImmediately(atRate: 1.0)//切歌了，总是把播放速率回归1.0，用户这是某首特定的歌要倍速，而不是每首歌都要倍速
        cancellable = NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime, object: item)
            .sink(receiveValue: { [weak self] _ in
                Self.handleDidPlayToEndTime(self: self)
            })
    }
    func setupAVAudioSession() {
        //默认是soloAmbient，在大多数手表上可以在后台继续播放，但是有少部分手表不行；所以我们设置playback，在全部手表上都能正常后台播放。
        //但是这样会突破静音模式按钮，这很危险，用户也可以在设置中选择尊重静音模式
        let targetCategories:AVAudioSession.Category = .playback
        do {
            try AVAudioSession.sharedInstance().setCategory(targetCategories, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
            print("✅AV Session configured: \(targetCategories.rawValue)")
        } catch {
            print("❌Failed to configure AV Session: \(error.localizedDescription)")
        }
    }

    func updateNowPlay(preferencedSeekModeRawValue: SeekPreference.RawValue) {
        if let currentMusic {
            //设置NowPlay控件响应
            configureRemoteCommandCenter(preferencedSeekModeRawValue:preferencedSeekModeRawValue)
            print("刷新了Now Play响应")
            //再开启NowPlay
            NowPlayHelper.updateNowPlayingInfoWith(currentMusic, playbackRate: avplayer.defaultRate)//.defaultRate和.rate的取值总是应该保持一致
        } else {
            print("Now Play不用刷新，因为没在播放")
        }
    }
    
    func configureRemoteCommandCenter(preferencedSeekModeRawValue: SeekPreference.RawValue) {
        remoteCommandManager.configureRemoteCommandCenter(avplayer: avplayer, playingList: playingList, userTapPreviousTrackButton: {
            self.userTapPreviousTrackButton()
        }, userTapNextTrackButton: {
            self.userTapNextTrackButton()
        }, needRefreshNowPlay: {
            self.updateNowPlay(preferencedSeekModeRawValue: preferencedSeekModeRawValue)
        }, preferencedSeekModeRawValue: preferencedSeekModeRawValue)
        
    }
    enum ItemInsertError:Error,LocalizedError {
        case noMusicURL
        case noCurrentItem
        case noCurrentItemIndex
        var errorDescription: String? {
            switch self {
            case .noMusicURL:
                "没有提供音乐链接"
            case .noCurrentItem:
                "找不到当前播放的音乐"
            case .noCurrentItemIndex:
                "找不到当前播放音乐的索引"
            }
        }
    }
    
    func updateError() {
        var errorMessage = ""
        //一行一条错误信息
        func addError(_ msg:String) {
            if errorMessage.isEmpty {
                errorMessage = msg
            } else {
                errorMessage += "\n"
                errorMessage += msg
            }
        }
        if let error = avplayer.error {
            addError("播放器："+error.localizedDescription)
        }
        if let error = avplayer.currentItem?.error {
            addError("音乐："+error.localizedDescription)
        }
        self.playingError = errorMessage
        var newWaitingPlayingReason:String = ""
        if avplayer.timeControlStatus == .waitingToPlayAtSpecifiedRate {
            if let reason = avplayer.reasonForWaitingToPlay {
                newWaitingPlayingReason = {
                    switch reason {
                    case .evaluatingBufferingRate://很快，要么变为toMinimizeStalls要么就开始播放了。
                        return ("正在加载中")
                    case .interstitialEvent:
                        return ("播放刚刚被打断了")
                    case .noItemToPlay:
                        return ("但没有音乐可以播放了，建议您换一首歌")
                    case .toMinimizeStalls:
                        return ("正在缓冲")
                    default:
                        return ("正在准备")
                    }
                }()
            }
        }
        self.waitingPlayingReason = newWaitingPlayingReason
    }
}

enum PlayingMode:Int {
    case singleLoop = 0
    case playingListLoop = 1
    case random = 2
    func humanReadbleName() -> String {
        switch self {
        case .singleLoop:
            "单曲循环"
        case .playingListLoop:
            "顺序播放"
        case .random:
            "随机"
        }
    }
}

extension MusicPlayerHolder {
    func updateCurrentMusic() {
        if let exsist = self.playingList.first(where: { music in
            music.id == self.currentMusic?.musicID
        }) {
            //正常的，什么都不做
        } else {
            //可能是用户从歌单里删除了当前正在播放的音乐，应该要停止播放
            stopPlaying()
        }
    }
    func stopPlaying() {
        avplayer.pause()
        self.currentMusic = nil
        avplayer.replaceCurrentItem(with: nil)
        NowPlayHelper.cleanNowPlayingInfo()
    }
}

// MARK: 切歌支持
extension MusicPlayerHolder {
    func switchMusic(to yiMusic:YiMusic) async throws {
        self.currentMusic = yiMusic
        let url:URL = try yiMusic.audioData.createTemporaryURL(extension: yiMusic.audioDataFileExtension)
        print("音乐链接\(url)")
        self.musicURL = url
        let item = AVPlayerItem(url: url)
        avplayer.replaceCurrentItem(with: item)
        let duration = item.duration
        self.lyricsData = await .init(music: yiMusic, duration: duration)
        guard !Task.isCancelled else { return }
        NowPlayHelper.updateNowPlayingInfoWith(yiMusic, playbackRate: 1.0)

        let currentRate = self.avplayer.defaultRate
        avplayer.defaultRate = 1.0//切歌了，总是把播放速率回归1.0，就像看视频倍速，用户是某首特定的歌要倍速，而不是每首歌都要倍速
        avplayer.rate = 1.0
        avplayer.playImmediately(atRate: 1.0)
        
        //因为AVPlayerItemDidPlayToEndTime是基于AVPlayerItem的，AVPlayerItem变了AVPlayerItemDidPlayToEndTime也要变
        cancellable = NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime, object: item)
            .sink(receiveValue: { [weak self] _ in
                Self.handleDidPlayToEndTime(self: self)
            })
    }
    static
    func handleDidPlayToEndTime(self:MusicPlayerHolder?) {
        if let self {
            self.switchMusicError = nil
            self.switchMusicTask?.cancel()
            self.switchMusicTask = Task {
                do {
                    switch self.playingMode {
                    case .singleLoop:
                        print("播放到结尾了，从头继续")
                        await self.avplayer.seek(to: CMTime.zero)
                        guard !Task.isCancelled else { return }
                        //在单曲循环时，保持倍速
                        let currentRate = self.avplayer.defaultRate
                        self.avplayer.playImmediately(atRate: currentRate)
                    case .playingListLoop:
                        print("播放到结尾了，切下一首")
                        try await self.switchMusic(to:try self.getNextMusic())
                    case .random:
                        print("播放到结尾了，切随机一首")
                        try await self.switchMusic(to:try self.getRandomMusic())
                    }
                } catch {
                    self.switchMusicError = error.localizedDescription
                }
            }
        } else {
            print("self已经销毁了")
        }
    }
    
    func userTapPreviousTrackButton() -> MPRemoteCommandHandlerStatus {
        switch self.playingMode {
        case .random:
            print("在随机模式，不支持切换到上一首歌")
            return .noActionableNowPlayingItem
        default:
            break
        }
        self.switchMusicError = nil
        self.switchMusicTask?.cancel()
        self.switchMusicTask = Task {
            do {
                switch self.playingMode {
                case .singleLoop,.playingListLoop:
                    print("在单曲循环或列表循环，点击上一曲按钮均切换到上一首歌")
                    try await self.switchMusic(to:try self.getPerviousMusic())
                case .random:
                    //更好的实现：如果这是本歌单播放过程中的第一首音乐，那么在随机时切上一首总是失败
                    //歌单中每播放一首歌，存入Array，然后在随机的时候点上一首，就是找到这个Array中的last-1项目，这样确保点上一首按钮，用户听到的总是字面意义上的“上一首”——也就符合用户操作的“我刚刚掠过了这首歌，现在我想再听一遍”。
                    break
                }
            } catch {
                self.switchMusicError = error.localizedDescription
            }
        }
        return .success
    }
    
    func userTapNextTrackButton() {
        self.switchMusicError = nil
        self.switchMusicTask?.cancel()
        self.switchMusicTask = Task {
            do {
                switch self.playingMode {
                case .singleLoop,.playingListLoop:
                    print("在单曲循环或列表循环，点击下一曲按钮均切换到下一首歌")
                    try await self.switchMusic(to:try self.getNextMusic())
                case .random:
                    print("用户点击下一曲，切随机一首")
                    try await self.switchMusic(to:try self.getRandomMusic())
                }
            } catch {
                self.switchMusicError = error.localizedDescription
            }
        }
    }
    enum GetNextMusicError:Error,LocalizedError {
        case emptyPlayingList
        case currentMusicNotInPlayingList
        case noItemInAnonEmptyArray
        var errorDescription: String? {
            switch self {
            case .noItemInAnonEmptyArray:
                "播放列表出现异常，请换一个歌单播放"
            case .currentMusicNotInPlayingList:
                "播放列表内容异常，请换一个歌单播放"
            case .emptyPlayingList:
                "播放列表中没有音乐了，请换一个歌单播放"
                
            }
        }
    }
    //不要真随机，不然前一首是A，下一首随机出来又是A，就尴尬了
    func getRandomMusic() throws -> YiMusic {
        if let currentMusic {
            playedItems.append(currentMusic.toShell())
        }
        let pickFrom:[YiMusicShell] = playingList.filter { music in
            !playedItems.contains(music)
        }
        print("歌单一共有\(playingList.count)，还剩\(pickFrom.count)首可以随机的")
        if pickFrom.isEmpty {
            //那说明歌单里每首歌都已经播放过了，那就随机选吧
            guard let randomOne = playingList.randomElement() else {
                throw GetNextMusicError.emptyPlayingList
            }
            return try musicShellToRealObject(randomOne)
        } else {
            //从歌单里还没有播放过的音乐中抽取
            guard let randomOne = pickFrom.randomElement() else {
                throw GetNextMusicError.noItemInAnonEmptyArray
            }
            return try musicShellToRealObject(randomOne)
        }
    }
    func getPerviousMusic() throws -> YiMusic {
        if self.playingList.isEmpty {
            //比如说用户播放过程中进行了垃圾清理？导致当前播放的这首歌都没了
            throw GetNextMusicError.emptyPlayingList
        } else if self.playingList.count == 1 {
            //比如说用户播放过程中进行了垃圾清理？导致当前播放的这首歌都没了
            if let currentMusic {
                return currentMusic
            } else {
                throw GetNextMusicError.emptyPlayingList
            }
        } else {
            guard let currentMusic else { throw GetNextMusicError.currentMusicNotInPlayingList }
            guard let currentCount = playingList.firstIndex(of: currentMusic.toShell()) else { throw GetNextMusicError.currentMusicNotInPlayingList }
            let previousIndex = currentCount - 1
            if previousIndex >= 0 {
                let switchTo = playingList[previousIndex]
                return try musicShellToRealObject(switchTo)
            } else {
                //既然已经是第一首了，再向上就来到播放列表的结尾
                if let lastMusic = playingList.last {
                    return try musicShellToRealObject(lastMusic)
                } else {
                    throw GetNextMusicError.emptyPlayingList
                }
            }
        }
    }
    func getNextMusic() throws -> YiMusic {
        if self.playingList.isEmpty {
            //比如说用户播放过程中进行了垃圾清理？导致当前播放的这首歌都没了
            throw GetNextMusicError.emptyPlayingList
        } else if self.playingList.count == 1 {
            //比如说用户播放过程中进行了垃圾清理？导致当前播放的这首歌都没了
            if let currentMusic {
                return currentMusic
            } else {
                throw GetNextMusicError.emptyPlayingList
            }
        } else {
            guard let currentMusic else { throw GetNextMusicError.currentMusicNotInPlayingList }
            guard let currentCount = playingList.firstIndex(of: currentMusic.toShell()) else { throw GetNextMusicError.currentMusicNotInPlayingList }
            let nextIndex = currentCount + 1
            if nextIndex <= playingList.count-1 {
                let nextOneShell = playingList[nextIndex]
                let nextOne = try musicShellToRealObject(nextOneShell)
                print("Current playing:\(currentMusic.name), next play:\(nextOne.name)")
                return nextOne
            } else {
                //该从头开始循环播放列表里
                if let firstMusic = playingList.first {
                    return try musicShellToRealObject(firstMusic)
                } else {
                    throw GetNextMusicError.emptyPlayingList
                }
            }
        }
    }
}

//管理正在播放的播放列表
struct ManagerPlayingList: ViewModifier {
    @Environment(MusicPlayerHolder.self)
    var playerHolder
    func body(content: Content) -> some View {
        content
        //初始打开不操作，万一用户在别的app也正在播放，一下给人家清空了多难受啊
            .onChange(of: playerHolder.playingList, initial: false) { oldValue, newValue in
                print("正在播放列表已更新")
                playerHolder.updateCurrentMusic()
            }
    }
}



extension MusicPlayerHolder {
    func currentTime() -> CMTime {
        avplayer.currentTime()
    }
    func queryDuration() throws -> CMTime {
        guard let duaration = avplayer.currentItem?.duration else {
            throw QueryDurationError.noCurrentItem
        }
        return duaration
    }
    enum QueryDurationError:Error,LocalizedError {
        case noCurrentItem
        var errorDescription: String? {
            switch self {
            case .noCurrentItem:
                "没有正在播放的音乐"
            }
        }
    }
}


