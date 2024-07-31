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
    static func convert(onlineSongs:[PlayListModel.PlayListSong],modelContext: ModelContext) async throws -> [YiMusic] {
        //歌单中的歌曲
        let allSongID:[String] = onlineSongs.map({ song in
            song.songID
        })
        
        //找到已经缓存的音乐中，有哪些是这个歌单的
        let predicate = #Predicate<YiMusic> { music in
            allSongID.contains(music.musicID)
        }
        let fetchDescriptor = FetchDescriptor<YiMusic>(predicate: predicate)
        let allResult = try modelContext.fetch(fetchDescriptor)
        

        //排序要与在线歌单内的保持一致
        var tempMusics:[YiMusic] = []
        for songID in allSongID {
            if let music = allResult.first(where: { music in
                music.musicID == songID
            }) {
                tempMusics.append(music)
            }
        }
        return tempMusics
    }
}
