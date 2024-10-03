//
//  RemoteCommandManager.swift
//  TuneWave
//
//  Created by Yukun Li on 2024/9/15.
//

import SwiftUI
import MediaPlayer

@MainActor
@Observable
class RemoteCommandManager {
    var playCommandTarget:Any? = nil
    var pauseCommandTarget:Any? = nil
    var rateCommandTarget:Any? = nil
    var previousTrackCommandTarget:Any? = nil
    var nextTrackCommandTarget:Any? = nil
    var skipForwardCommandTarget:Any? = nil
    var skipBackwardCommandTarget:Any? = nil
    var needRefreshNowPlay:(()->())? = nil
    
    
    // 配置远程控制事件
    // 不配置这个，不会在Now Play显示歌曲信息
    // 这里的几个闭包，在调用前都应该检查self还存不存在的
    func configureRemoteCommandCenter(avplayer:AVPlayer,playingList:[YiMusicShell],userTapPreviousTrackButton:@escaping () -> (MPRemoteCommandHandlerStatus),userTapNextTrackButton:@escaping () -> (),needRefreshNowPlay:@escaping ()->(),preferencedSeekModeRawValue:SeekPreference.RawValue) {
        self.needRefreshNowPlay = needRefreshNowPlay
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
        commandCenter.playCommand.removeTarget(playCommandTarget)
        playCommandTarget = commandCenter.playCommand.addTarget { [weak self] event in
            if let self {
                //暂停和继续应该尊重倍速
                let defaultRate = avplayer.defaultRate
                avplayer.playImmediately(atRate: defaultRate)
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
        commandCenter.pauseCommand.removeTarget(pauseCommandTarget)
        pauseCommandTarget = commandCenter.pauseCommand.addTarget { [weak self] event in
            if let self {
                avplayer.pause()
                return .success
            } else {
                return .noSuchContent
            }
        }
        
        
        
        
        //“博客”app里也有倍速的控件
        commandCenter.changePlaybackRateCommand.isEnabled = true
        commandCenter.changePlaybackRateCommand.supportedPlaybackRates = [0.5,0.75,1.0,1.25,1.5,2,3,4,5]
        commandCenter.changePlaybackRateCommand.removeTarget(rateCommandTarget)
        rateCommandTarget = commandCenter.changePlaybackRateCommand.addTarget { [weak self] event in
            if let self {
                if let rater = event as? MPChangePlaybackRateCommandEvent {
                    avplayer.defaultRate = rater.playbackRate//设置好defaultRate，这样在单曲循环、暂停继续的时候，可以利用这个rate信息
                    avplayer.rate = rater.playbackRate
                    self.needRefreshNowPlay?()//需要手动通知更新NowPlay的倍速，而不是return .success就好了
                    return .success
                } else {
                    return .commandFailed
                }
            } else {
                return .noSuchContent
            }
        }
        let policy:Policy = {
            //如果播放列表歌曲数量大于1，支持切歌
            if playingList.count > 1 {
                if preferencedSeekModeRawValue == SeekPreference.song.rawValue {
                    return .previousAndNextTrackCommandOnly
                } else {
                    //耳机双击可以切歌，但是UI按钮显示+10s -10s
                    return .bothCommandButPreferredPreviousAndNextTrackCommand
                }
            } else {
                //如果只有一首歌，就显示快进快退
                return .skipBackwardCommandOnly
            }
        }()
        switch policy {
        case .previousAndNextTrackCommandOnly:
            claenSkipForwardAndBackwardCommand(commandCenter: commandCenter)
            addPreviousAndNextTrackCommand(commandCenter: commandCenter, userTapPreviousTrackButton: userTapPreviousTrackButton, userTapNextTrackButton: userTapNextTrackButton)
        case .bothCommandButPreferredPreviousAndNextTrackCommand:
                //同时支持切歌和快进快退，系统会响应耳机切歌的同时优先显示快进快退。
            addPreviousAndNextTrackCommand(commandCenter: commandCenter, userTapPreviousTrackButton: userTapPreviousTrackButton, userTapNextTrackButton: userTapNextTrackButton)
            addSkipBackwardCommand(commandCenter: commandCenter, avplayer: avplayer)
        case .skipBackwardCommandOnly:
            cleanPreviousAndNextTrackCommand(commandCenter:commandCenter)
            addSkipBackwardCommand(commandCenter: commandCenter, avplayer: avplayer)
        }
    }
    enum Policy {
        case previousAndNextTrackCommandOnly
        case bothCommandButPreferredPreviousAndNextTrackCommand
        case skipBackwardCommandOnly
    }
    func claenSkipForwardAndBackwardCommand(commandCenter:MPRemoteCommandCenter) {
        //⬇️清理快进快退操作，以便让切歌按钮能显示出来
        commandCenter.skipForwardCommand.isEnabled = false
        commandCenter.skipForwardCommand.removeTarget(skipForwardCommandTarget)
        
        
        commandCenter.skipBackwardCommand.isEnabled = false
        commandCenter.skipBackwardCommand.removeTarget(skipBackwardCommandTarget)
        print("清理了快进快退操作")
        //⬆️清理快进快退操作，以便让切歌按钮能显示出来
    }
    func cleanPreviousAndNextTrackCommand(commandCenter:MPRemoteCommandCenter) {
        //如果只有一首歌，就显示快进快退
            //⬇️清理切歌操作，因为它们已经没有正确的实现了
            commandCenter.previousTrackCommand.isEnabled = false
            commandCenter.previousTrackCommand.removeTarget(previousTrackCommandTarget)
            
            commandCenter.nextTrackCommand.isEnabled = false
            commandCenter.nextTrackCommand.removeTarget(nextTrackCommandTarget)
            print("清理了切歌操作")
            //⬆️清理切歌操作，因为它们已经没有正确的实现了
    }
    func addSkipBackwardCommand(commandCenter:MPRemoteCommandCenter,avplayer:AVPlayer) {
        commandCenter.skipForwardCommand.isEnabled = true
        commandCenter.skipForwardCommand.removeTarget(skipForwardCommandTarget)
        
        skipForwardCommandTarget = commandCenter.skipForwardCommand.addTarget { [weak self] event in
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
        commandCenter.skipBackwardCommand.removeTarget(skipBackwardCommandTarget)
        skipBackwardCommandTarget = commandCenter.skipBackwardCommand.addTarget { [weak self] event in
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
    }
    func addPreviousAndNextTrackCommand(commandCenter:MPRemoteCommandCenter,userTapPreviousTrackButton:@escaping () -> (MPRemoteCommandHandlerStatus),userTapNextTrackButton:@escaping () -> ()) {
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.removeTarget(previousTrackCommandTarget)
        previousTrackCommandTarget = commandCenter.previousTrackCommand.addTarget { [weak self] event in
            if let self {
                //因为切歌操作是async的，但是这个addTarget是同步的，所以这里就没法处理错误了。
                return userTapPreviousTrackButton()
            } else {
                return .noSuchContent
            }
        }
        
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.removeTarget(nextTrackCommandTarget)
        nextTrackCommandTarget = commandCenter.nextTrackCommand.addTarget { [weak self] event in
            if let self {
                //因为切歌操作是async的，但是这个addTarget是同步的，所以这里就没法处理错误了。
                userTapNextTrackButton()
                return .success
            } else {
                return .noSuchContent
            }
        }
    }
}
