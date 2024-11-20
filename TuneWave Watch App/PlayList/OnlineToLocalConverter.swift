//
//  OnlineToLocalConverter.swift
//  TuneWave Watch App
//
//  Created by Yukun Li on 2024/7/31.
//

import Foundation
import SwiftUI
import SwiftData

@MainActor
struct OnlineToLocalConverter {
    static func convert(onlineSongs:[PlayListModel.PlayListSong],modelContext: ModelContext) async throws -> [YiMusicDetailedShell] {
        //歌单中的歌曲
        let allSongID:[String] = onlineSongs.map({ song in
            song.songID
        })
        
        

        //排序要与在线歌单内的保持一致
        var tempMusics:[YiMusicDetailedShell] = []
        for songID in allSongID {
            if let music = try modelContext.fetch(.init(predicate: #Predicate<YiMusic> { music in
                music.musicID == songID
            })).first {
                tempMusics.append(try await music.toDetailedShell())
            } else {
                //说明这首歌还没有被缓存/下载呗
            }
        }
        return tempMusics
    }
}
