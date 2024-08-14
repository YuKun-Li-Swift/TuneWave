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


@Observable
class MusicPlayerHolder {
    let avplayer = AVPlayer()
    var musicURL:URL? = nil
    //正在播放的歌单
    var playingList:[YiMusic] = []
    var currentMusic:YiMusic? = nil
    var cancellable:AnyCancellable?
    var lyricsCancellable:Any?
    
    var playingError:String = ""
    var waitingPlayingReason:String = ""
    var playingMode:PlayingMode = .singleLoop
    init() {
        //每次变化了就由SavePlayingModeChange来保存
        if let hasRemember = UserDefaults.standard.value(forKey: "TuneWavePlayingMode") as? Int,let rememberMode = PlayingMode(rawValue: hasRemember) {
            self.playingMode = rememberMode
        } else {
            //没有记忆，默认使用单曲循环
        }
    }
    var switchMusicError:String? = nil
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
        var errorDescription: String? {
            switch self {
            case .notRightPlayingList:
                "歌单出现异常，请换一个歌单播放"
            }
        }
    }
    //playingList是当前歌曲的上下文，目前的策略是，当前歌曲从哪一个歌单里来的，就把播放列表替换为那个歌单。
    //如果播放的这首歌已经被缓存了，那么playingList就会包含这首歌
    //如果播放的这首歌，在点击音乐Row时尚未被缓存，那么playingList就不包含这首歌
    func playMusic(_ yiMusic:YiMusic,playingList:[YiMusic]) throws {
  
        if !playingList.contains(yiMusic) {
            throw PlayMusicError.notRightPlayingList
        }
        self.playingList = playingList
        self.currentMusic = yiMusic
        let url:URL = try yiMusic.audioData.createTemporaryURL(extension: yiMusic.audioDataFileExtension)
        print("音乐链接\(url)")
        self.musicURL = url
        let item = AVPlayerItem(url: url)
        avplayer.replaceCurrentItem(with: item)
        avplayer.audiovisualBackgroundPlaybackPolicy = .continuesIfPossible
        avplayer.actionAtItemEnd = .none

        configureRemoteCommandCenter()
        NowPlayHelper.updateNowPlayingInfoWith(yiMusic)
        avplayer.defaultRate = 1.0
        avplayer.rate = 1.0
        avplayer.playImmediately(atRate: 1.0)
        cancellable = NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime, object: item)
            .sink(receiveValue: { [weak self] _ in
                Self.handleDidPlayToEndTime(self: self)
            })
    }
    var playedItems:[YiMusic] = []
    func setupAVAudioSession() {
        //默认是soloAmbient，在大多数手表上可以在后台继续播放，但是有少部分手表不行；所以我们设置playback，在全部手表上都能正常后台播放。
        let targetCategories:AVAudioSession.Category = .playback
        do {
            try AVAudioSession.sharedInstance().setCategory(targetCategories, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
            print("✅AV Session configured: \(targetCategories.rawValue)")
        } catch {
            print("❌Failed to configure AV Session: \(error.localizedDescription)")
        }
    }

    func updateNowPlay() {
        if let currentMusic {
            //设置NowPlay控件响应
            configureRemoteCommandCenter()
            //再开启NowPlay
            NowPlayHelper.updateNowPlayingInfoWith(currentMusic)
        } else {
            print("Now Play不用刷新，因为没在播放")
        }
    }
    // 配置远程控制事件
    // 不配置这个，不会在Now Play显示歌曲信息
    func configureRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
//        commandCenter.playCommand.addTarget { [weak self] event in
//            if let self {
//                if self.avplayer.timeControlStatus == .paused {
//                    self.avplayer.playImmediately(atRate: 1.0)
//                    return .success
//                }
//            }
//            return .commandFailed
//        }
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] event in
            if let self {
                avplayer.playImmediately(atRate: 1.0)
                return .success
            } else {
                return .noSuchContent
            }
        }
        
//        commandCenter.pauseCommand.addTarget { [weak self] event in
//            if let self {
//                if self.avplayer.timeControlStatus == .playing && self.avplayer.timeControlStatus == .waitingToPlayAtSpecifiedRate {
//                    self.avplayer.pause()
//                    return .success
//                }
//            }
//            return .commandFailed
//        }
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] event in
            if let self {
                avplayer.pause()
                return .success
            } else {
                return .noSuchContent
            }
        }
        
        // 其他远程控制命令可以在这里添加，如下一首、上一首等
        commandCenter.previousTrackCommand.isEnabled = false
        commandCenter.nextTrackCommand.isEnabled = false
        
        commandCenter.skipForwardCommand.isEnabled = true
        commandCenter.skipForwardCommand.addTarget { [weak self] event in
            if let self {
                do {
                    //因为Now Play的UI上显示的总是10秒
                    try avplayer.add10Seconds()
                    return .success
                } catch {
                    if let error = error as? NowPlaySeekError {
                        return error.toMPRemoteCommandHandlerStatus()
                    } else {
                        #if DEBUG
                        fatalError("不应该跑这里来")
                        #endif
                        return .commandFailed
                    }
                }
            } else {
                return .noSuchContent
            }
        }
        commandCenter.skipBackwardCommand.isEnabled = true
        commandCenter.skipBackwardCommand.addTarget { [weak self] event in
            if let self {
                do {
                    //因为Now Play的UI上显示的总是10秒
                    try avplayer.subtract10Seconds()
                    return .success
                } catch {
                    if let error = error as? NowPlaySeekError {
                        return error.toMPRemoteCommandHandlerStatus()
                    } else {
                        #if DEBUG
                        fatalError("不应该跑这里来")
                        #endif
                        return .commandFailed
                    }
                }
            } else {
                return .noSuchContent
            }
        }
        
        //“博客”app里也有倍速的控件
        commandCenter.changePlaybackRateCommand.isEnabled = true
        commandCenter.changePlaybackRateCommand.supportedPlaybackRates = [0.5,0.75,1,1.25,1.5,2,3,4,5]
        //目前仅对这首歌有效，切换音乐的时候会重置为1.0的
        commandCenter.skipBackwardCommand.addTarget { [weak self] event in
            if let self {
                if let rater = event as? MPChangePlaybackRateCommandEvent {
                    avplayer.defaultRate = rater.playbackRate
                    avplayer.rate = rater.playbackRate
                    return .success
                } else {
                    return .commandFailed
                }
            } else {
                return .noSuchContent
            }
        }
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
        
        if avplayer.timeControlStatus == .waitingToPlayAtSpecifiedRate {
            if let reason = avplayer.reasonForWaitingToPlay {
                self.waitingPlayingReason = {
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
            music.musicID == self.currentMusic?.musicID
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
    func switchMusic(to yiMusic:YiMusic) throws {
        self.currentMusic = yiMusic
        let url:URL = try yiMusic.audioData.createTemporaryURL(extension: yiMusic.audioDataFileExtension)
        print("音乐链接\(url)")
        self.musicURL = url
        let item = AVPlayerItem(url: url)
        avplayer.replaceCurrentItem(with: item)
     
        NowPlayHelper.updateNowPlayingInfoWith(yiMusic)

        let currentRate = self.avplayer.defaultRate
        avplayer.playImmediately(atRate: currentRate)//保持播放速率不变
        
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
            do {
                switch self.playingMode {
                case .singleLoop:
                    print("播放到结尾了，从头继续")
                    self.avplayer.seek(to: CMTime.zero)
                    //可能被通过Now Play更改了，不是1.0
                    let currentRate = self.avplayer.defaultRate
                    self.avplayer.playImmediately(atRate: currentRate)
                case .playingListLoop:
                    print("播放到结尾了，切下一首")
                    try self.switchMusic(to:try self.getNextMusic())
                case .random:
                    print("播放到结尾了，切随机一首")
                    try self.switchMusic(to:try self.getRandomMusic())
                }
            } catch {
                self.switchMusicError = error.localizedDescription
            }
           
        } else {
            print("self已经销毁了")
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
            playedItems.append(currentMusic)
        }
        let pickFrom:[YiMusic] = playingList.filter { music in
            !playedItems.contains(music)
        }
        print("歌单一共有\(playingList.count)，还剩\(pickFrom.count)首可以随机的")
        if pickFrom.isEmpty {
            //那说明歌单里每首歌都已经播放过了，那就随机选吧
            guard let randomOne = playingList.randomElement() else {
                throw GetNextMusicError.emptyPlayingList
            }
            return randomOne
        } else {
            //从歌单里还没有播放过的音乐中抽取
            guard let randomOne = pickFrom.randomElement() else {
                throw GetNextMusicError.noItemInAnonEmptyArray
            }
            return randomOne
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
            guard let currentCount = playingList.firstIndex(of: currentMusic) else { throw GetNextMusicError.currentMusicNotInPlayingList }
            let nextIndex = currentCount + 1
            if nextIndex <= playingList.count-1 {
                let nextOne = playingList[nextIndex]
                return nextOne
            } else {
                //该从头开始循环播放列表里
                if let firstMusic = playingList.first {
                    return firstMusic
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


import MediaPlayer

//这个结构体帮助设置Now Play中显示的歌曲信息
struct NowPlayHelper {
    static
    func updateNowPlayingInfoWith(_ yiMusic:YiMusic) {
        updateNowPlayingInfo(songTitle: yiMusic.name, artistName: yiMusic.artist, albumArtData: yiMusic.albumImg)
    }
    static
    func updateNowPlayingInfo(songTitle: String, artistName: String, albumArtData: Data) {
        // 更新Now Playing信息
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = songTitle  // 设置歌曲名
        nowPlayingInfo[MPMediaItemPropertyArtist] = artistName // 设置艺术家名
        
        // 设置封面图片（可选）
         let albumArtData = albumArtData
        if let image = UIImage(data: albumArtData) {
            nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { size in
                return image
            }
        } else {
            nowPlayingInfo[MPMediaItemPropertyArtwork] = nil
        }
        // 将信息传递给MPNowPlayingInfoCenter
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    static
    func cleanNowPlayingInfo() {
        // 更新Now Playing信息
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = nil  // 设置歌曲名
        nowPlayingInfo[MPMediaItemPropertyArtist] = nil // 设置艺术家名
        nowPlayingInfo[MPMediaItemPropertyArtwork] = nil // 设置封面图片
        // 将信息传递给MPNowPlayingInfoCenter
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
}

