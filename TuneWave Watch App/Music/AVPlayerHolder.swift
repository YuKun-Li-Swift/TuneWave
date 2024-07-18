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

@Observable
class MusicPlayerHolder {
    let avplayer = AVPlayer()
    var musicURL:URL? = nil
    var yiMusic:YiMusic? = nil
    var cancellable:AnyCancellable?
    var lyricsCancellable:Any?
    var playingError:String = ""
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
    //AVQueuePlayer支持耳机线控切歌
    func playMusic(_ yiMusic:YiMusic) throws {
        self.yiMusic = yiMusic
        let url:URL = try yiMusic.audioData.createTemporaryURL(extension: yiMusic.audioDataFileExtension)
        print("音乐链接\(url)")
        self.musicURL = url
        let item = AVPlayerItem(url: url)
        avplayer.replaceCurrentItem(with: item)
        avplayer.audiovisualBackgroundPlaybackPolicy = .continuesIfPossible
        avplayer.actionAtItemEnd = .none
        configureRemoteCommandCenter()
        NowPlayHelper.updateNowPlayingInfoWith(yiMusic)
        avplayer.playImmediately(atRate: 1.0)
        cancellable = NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime, object: item)
            .sink(receiveValue: { [weak self] _ in
                print("播放到结尾了，从头继续")
                if let self {
                    avplayer.seek(to: CMTime.zero)
                    avplayer.playImmediately(atRate: 1.0)
                } else {
                    print("self已经销毁了")
                }
            })
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
        
        commandCenter.playCommand.addTarget { [self] event in
            avplayer.playImmediately(atRate: 1.0)
            return .success
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
        
        commandCenter.pauseCommand.addTarget { [self] event in
            avplayer.pause()
            return .success
        }
        
        // 其他远程控制命令可以在这里添加，如下一首、上一首等
        commandCenter.previousTrackCommand.isEnabled = false
        commandCenter.nextTrackCommand.isEnabled = false
        
        commandCenter.skipForwardCommand.isEnabled = true
        commandCenter.skipForwardCommand.addTarget { [self] event in
            avplayer.seek(to: avplayer.currentTime() + CMTime(value: 15, timescale: 60), toleranceBefore: .zero, toleranceAfter: .zero)
            return .success
        }
        commandCenter.skipBackwardCommand.isEnabled = true
        commandCenter.skipBackwardCommand.addTarget { [self] event in
            avplayer.seek(to: avplayer.currentTime() - CMTime(value: 15, timescale: 60), toleranceBefore: .zero, toleranceAfter: .zero)
            return .success
        }
        
        commandCenter.ratingCommand.isEnabled = true
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
        
        if avplayer.timeControlStatus == .waitingToPlayAtSpecifiedRate {
            if let reason = avplayer.reasonForWaitingToPlay {
                switch reason {
                case .evaluatingBufferingRate:
                    addError("正在检测网速。")
                case .interstitialEvent:
                    addError("播放器正在等待间隙事件完成。")
                case .noItemToPlay:
                    addError("播放器闲置，因为没有音乐可以播放了。")
                case .toMinimizeStalls:
                    addError("正在缓冲。")
                default:
                    addError("无法播放，但不明原因。")
                }
            }
        }
        self.playingError = errorMessage
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
}
