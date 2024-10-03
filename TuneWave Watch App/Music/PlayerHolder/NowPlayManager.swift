//
//  NowPlay.swift
//  TuneWave
//
//  Created by Yukun Li on 2024/9/15.
//


import MediaPlayer
import SwiftUI

//这个结构体帮助设置Now Play中显示的歌曲信息
struct NowPlayHelper {
    static
    func updateNowPlayingInfoWith(_ yiMusic:YiMusic,playbackRate:Float) {
        updateNowPlayingInfo(songTitle: yiMusic.name, artistName: yiMusic.artist, playbackRate: playbackRate, albumArtData: yiMusic.albumImg)
    }
    static
    func updateNowPlayingInfo(songTitle: String, artistName: String,playbackRate:Float, albumArtData: Data) {
        // 更新Now Playing信息
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = songTitle  // 设置歌曲名
        nowPlayingInfo[MPMediaItemPropertyArtist] = artistName // 设置艺术家名
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = playbackRate
        
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
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = nil
        nowPlayingInfo[MPMediaItemPropertyArtwork] = nil // 设置封面图片
        // 将信息传递给MPNowPlayingInfoCenter
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
}
