//
//  LyricsModel.swift
//  TuneWave Watch App
//
//  Created by Yukun Li on 2024/8/23.
//

import Foundation
import SwiftUI
import CoreMedia
import Combine
//这个类负责存储解析好的歌词，获取匹配当前时间点的歌词
struct LyricsData:Identifiable,Equatable {
    var id = UUID()
    var parsedLyrics: [LyricsModel.LyricsLine] = []
    var parsedTranslateLyrics: [LyricsModel.LyricsLine] = []
    init(music:YiMusic,duration:CMTime) async {
        
        let actor = LyricsModel()
        
        parsedTranslateLyrics = await actor.parseLyrics(music.tlyric, duration: duration)
//        print("歌词译文\(music.tlyric)")
//        print("歌词译文（解析）\(parsedTranslateLyrics.map({ i in i.content }))")
        
        parsedLyrics = await actor.parseLyrics(music.lyric, duration: duration)
//        print("歌词原文\(music.lyric)")
//        print("歌词原文（解析）\(parsedLyrics.map({ i in i.content }))")
    }
}

@MainActor
@Observable
class LyricsViewModelV1 {
    //可能会有多行在同一个时间点，怎么处理看外界函数
    private func linesAtTime(date: CMTime,parsedLyrics:[LyricsModel.LyricsLine]) -> [LyricsModel.LyricsLine] {
        // 初始化一个空数组来存储匹配的歌词行
        var matchingLines: [LyricsModel.LyricsLine] = []
        
        // 遍历已解析的歌词，找到在给定时间范围内的所有歌词行
        for line in parsedLyrics {
            if line.time.contains(date) {
                matchingLines.append(line)
            }
        }
        
        // 返回所有匹配的歌词行
        return matchingLines
    }
    func updateLineAtTime(date: CMTime,parsedLyrics:[LyricsModel.LyricsLine]) -> LyricsModel.LyricsLine? {
        //如果在同一个时间点有多行，随机选择一行。如果这个时间点没有歌词，就返回nil
        return linesAtTime(date: date,parsedLyrics:parsedLyrics).randomElement()
    }
}

@MainActor
@Observable
class LyricsViewModel {
    var currentShowingLyricBelongMuic:String = ""//音乐ID
    var parseError:String? = nil
    var parsedLyrics: [LyricsModel.LyricsLine] = []
    let actor = LyricsModel()
    func parseLyricsWithCustomAnimation(_ text:String,musicDuration:CMTime,animation:Animation?) async {
        
        let result = await actor.parseLyrics(text, duration: musicDuration)
        withAnimation(animation) {
            self.parsedLyrics = result
        }
    }
    //可能会有多行在同一个时间点，怎么处理看外界函数
    private func linesAtTime(date: CMTime) -> [LyricsModel.LyricsLine] {
        // 初始化一个空数组来存储匹配的歌词行
        var matchingLines: [LyricsModel.LyricsLine] = []
        
        // 遍历已解析的歌词，找到在给定时间范围内的所有歌词行
        for line in parsedLyrics {
            if line.time.contains(date) {
                matchingLines.append(line)
            }
        }
        
        // 返回所有匹配的歌词行
        return matchingLines
    }
    func updateLineAtTime(date: CMTime) -> LyricsModel.LyricsLine? {
        //如果在同一个时间点有多行，随机选择一行。如果这个时间点没有歌词，就返回nil
        return linesAtTime(date: date).randomElement()
    }
}

//分离到单独的actor，以便解析操作不阻塞主线程
//这个类只负责解析歌词，源码参考自https://github.com/jayasme/SpotlightLyrics
actor LyricsModel {
    struct LyricsLine: Identifiable,Hashable,Equatable {
        var id = UUID()
        var content: String
        var time: ClosedRange<CMTime>
        static
        func placeHolder() -> Self {
            return .init(content: "", time: CMTime.invalid...CMTime.invalid)
        }
    }
    
    func parseLyrics(_ LRC: String,duration:CMTime) -> [LyricsLine] {
        var lyricsLines: [LyricsLine] = []
        let lines = LRC.components(separatedBy: .newlines)
        
        var previousTime: CMTime = .zero
        var previousContent: String? = nil
        
        for line in lines {
            guard !line.isEmpty else { continue }
            
            var cLine = line
            var timeTags: [CMTime] = []
            
            while cLine.hasPrefix("[") {
                guard let endIndex = cLine.range(of: "]")?.upperBound else { break }
                let timeTag = String(cLine[cLine.index(after: cLine.startIndex)..<cLine.index(before: endIndex)])
                cLine.removeSubrange(cLine.startIndex..<endIndex)
                
                let timeComponents = timeTag.components(separatedBy: ":")
                if timeComponents.count == 2 {
                    if let minutes = Double(timeComponents[0]), let seconds = Double(timeComponents[1]) {
                        let time = CMTime(seconds: minutes * 60 + seconds, preferredTimescale: 600)
                        timeTags.append(time)
                    }
                }
            }
            
            let content = cLine.trimmingCharacters(in: .whitespacesAndNewlines)
            
            for time in timeTags {
                if let prevContent = previousContent {
                    let endTime = (time - CMTime(seconds: 0.01, preferredTimescale: 600))
                    //避免结束时间小于开始时间导致闪退
                    if endTime >= previousTime {
                        let timeRange = previousTime...endTime
                        lyricsLines.append(LyricsLine(content: prevContent, time: timeRange))
                    } else {
                        let timeRange = previousTime...previousTime
                        lyricsLines.append(LyricsLine(content: prevContent, time: timeRange))
                    }
                }
                previousTime = time
                previousContent = content
            }
        }
        
        // 处理最后一行的时间范围
        if let lastContent = previousContent {
            //避免duration小于最后一行歌词的开始时间导致闪退，比如说试听片段的时候会出现这种情况
            if duration >= previousTime {
                let lastRange = previousTime...duration
                lyricsLines.append(LyricsLine(content: lastContent, time: lastRange))
            } else {
                let lastRange = previousTime...previousTime
                lyricsLines.append(LyricsLine(content: lastContent, time: lastRange))
            }
            
        }
        let isAllEmptyLyrics:Bool = lyricsLines.allSatisfy({ line in
            line.content.isEmpty
        })
        guard !isAllEmptyLyrics else { return [] }
        //避免了“让风告诉你”的英文翻译是只有时间戳、内容全空白⬇️，这种情况在这边直接做拦截了，而不是让视图去判断
        [03:01.257]
        [03:05.006]
        [03:09.241]
        [03:13.139]
        return lyricsLines
    }
}
