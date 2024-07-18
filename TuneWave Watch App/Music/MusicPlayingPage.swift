//
//  MusicPlayingPage.swift
//  TuneWave Watch App
//
//  Created by Yukun Li on 2024/7/16.
//

import SwiftUI

import WatchKit
struct NowPlayView: View {
    @Environment(MusicPlayerHolder.self)
    var playerHolder:MusicPlayerHolder
    @State
    private var selectedTab = 0
    @State
    private var showMorePage = false
    @State
    var errorCheckTimer = Timer.publish(every: 1, tolerance: 1, on: .main, in: .default).autoconnect()
    @State
    var showErrorAlert = false
    @State
    var isAutoScrolling = true
    @State
    var showAutoScrollTip = false
    var body: some View {
        
        ZStack {
            VStack {
                
                
                VStack(content: {
                    TabView(selection: $selectedTab, content: {
                        NowPlayingView()
                            .tag(0)
                        LyricsView(isAutoScrolling: $isAutoScrolling)
                            .tag(1)
                    })
                })
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        if selectedTab == 0 {
                            Button {
                                showMorePage = true
                            } label: {
                                Label("更多操作", systemImage: "ellipsis")
                            }
                        } else {
                            Button {
                                withAnimation(.easeOut) {
                                    isAutoScrolling.toggle()
                                }
                            } label: {
                                Label(isAutoScrolling ? "点此关闭歌词自动滚动" : "点此打开歌词自动滚动", systemImage: isAutoScrolling ? "hand.raised" : "hand.raised.slash")
                                    .transition(.symbolEffect(.automatic))
                            }
                            
                        }
                    }
                }
                .navigationDestination(isPresented: $showMorePage, destination: {
                    Text("更多操作")
                })
                
                .onReceive(errorCheckTimer, perform: { _ in
                    playerHolder.updateError()
                })
                
                .modifier(ShowAutoScrollTip(isAutoScrolling: isAutoScrolling, showTip: showTip))
                
            }
            .opacity((playerHolder.playingError.isEmpty) ? 1 : 0)
            .allowsHitTesting((playerHolder.playingError.isEmpty) ? true : false)
            
            AutoScrollTipView(isAutoScrolling:$isAutoScrolling,showAutoScrollTip: $showAutoScrollTip)
            
            VStack {
                if !playerHolder.playingError.isEmpty {
                    ScrollViewOrNot {
                        ErrorView(errorText: playerHolder.playingError)
                    }
                }
            }
        }
        .animation(.smooth, value: playerHolder.playingError)
    }
    
    
}

// MARK: 切换自动滚动开关的时候显示一个小横幅
struct ShowAutoScrollTip: ViewModifier {
    var isAutoScrolling:Bool
    var showTip:()->()
    func body(content: Content) -> some View {
        content
            .onChange(of: isAutoScrolling, initial: false) { oldValue, newValue in
                if oldValue != newValue {
                    showTip()
                }
            }
    }
}


extension NowPlayView {
    func showTip() {
        Task { @MainActor in
            withAnimation(.snappy) {
                showAutoScrollTip = true
            }
            try? await Task.sleep(nanoseconds: 1000000000)//1s
            withAnimation(.snappy) {
                showAutoScrollTip = false
            }
        }
    }
}
struct AutoScrollTipView: View {
    @Binding
    var isAutoScrolling:Bool
    @Binding
    var showAutoScrollTip:Bool
    var body: some View {
        if showAutoScrollTip {
            VStack {
                Spacer()
                Text("自动滚动已\(isAutoScrolling ? "打开" : "关闭")")
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.accentColor.opacity(0.8)).fill(Material.ultraThin))
            }
            .transition(.move(edge: .bottom))
        }
    }
}
//⬆️MARK: 切换自动滚动开关的时候显示一个小横幅

//页面不可见的时候不更新滚动歌词，避免浪费资源
@MainActor
struct LyricsView: View {
    @Environment(MusicPlayerHolder.self)
    var playerHolder:MusicPlayerHolder
    @State
    var vm = LyricsViewModel()
    @State
    var focusLyrics:LyricsModel.LyricsLine? = nil
    @Binding
    var isAutoScrolling:Bool
    @AppStorage("enableLyricsTranslate")
    var enableLyricsTranslate = false
    @State
    var haveLyric = true
    var body: some View {
        VStack {
            if let music = playerHolder.yiMusic {
                VStack {
                    if haveLyric {
                        //在常亮状态下，要求30帧刷新歌词。否则会停止滚动（静止在一行）。
                        //常见：写作业，手表戴在手腕上，想看滚动歌词的时候瞟一眼。
                        //骑车听歌，想看歌词的时候瞟一眼。
                        TimelineView(.periodic(from: .now, by: 1/30), content: { _ in
                            VStack {
                                ScrollView(.vertical) {
                                    VStack(alignment: .leading,spacing:23.3) {
                                        ForEach(vm.parsedLyrics) { lyric in
                                            LyricsLineView(lyric: lyric,focusLyrics:$focusLyrics)
                                                .transition(.blurReplace)
                                                .id(lyric)
                                        }
                                    }
                                    .scenePadding(.horizontal)
                                    .scrollTargetLayout()
                                    .padding(.vertical,67)
                                }
                                .scrollPosition(id: $focusLyrics, anchor: .center)
                            }
                        })
                        .overlay(alignment: .center, content: {
                            if vm.parsedLyrics.isEmpty {
                                Zero3Delay {
                                    Text("歌词为空")
                                }
                                //给0.3秒的时间来解析歌词，如果0.3秒后还是空的，说明解析歌词的函数出错了
                            }
                        })
                        .navigationTitle("歌词")
                        .onLoad {
                            Task {
                                await loadLyric(music: music, translate: enableLyricsTranslate)
                                //歌词加载完成需要主动滚动一次，但是不用延迟
                                enableAutoScroll(.onLoad)
                            }
                        }
                        .onAppear {
                            //页面onAppear需要主动滚动一次，但是要延迟
                            enableAutoScroll(.onAppear)
                        }
                        .onDisappear {
                            disableAutoScroll()
                        }
                        .onChange(of: isAutoScrolling, initial: false) {  oldValue, newValue in
                            if newValue {
                                //isAutoScrolling打开时需要主动滚动一次（此时歌词在的，需要有动画）
                                enableAutoScroll(.withAnimation)
                            } else {
                                disableAutoScroll()
                            }
                        }
                        .transition(.blurReplace)
                    } else {
                        if !enableLyricsTranslate {
                            Text("这首音乐没有歌词")
                                .transition(.blurReplace)
                        } else {
                            Text("这首歌没有翻译歌词")
                                .transition(.blurReplace)
                        }
                    }
                }
                .onChange(of: enableLyricsTranslate, initial: false) { oldValue, newValue in
                    updateHaveLyricState(music: music)
                    //重新加载歌词+重新滚动
                    Task {
                        await loadLyric(music: music, translate: newValue)
                        //歌词加载完成需要主动滚动一次，但是不用延迟
                        enableAutoScroll(.onLoad)
                    }
                }
                .animation(.smooth, value: haveLyric)
            } else {
                Text("当前没有播放的音乐")
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                Rectangle()
                    .frame(width: 1, height: 1, alignment: .center)
                    .hidden()
                Rectangle()
                    .frame(width: 1, height: 1, alignment: .center)
                    .hidden()
                Button {
                    enableLyricsTranslate.toggle()
                } label: {
                    Label("歌词翻译", systemImage: "translate")
                }
            }
        }
        .animation(.smooth, value: enableLyricsTranslate)
        .animation(.smooth, value: haveLyric)
        
    }
    func updateHaveLyricState(music:YiMusic) {
        if self.enableLyricsTranslate {
            self.haveLyric = !music.tlyric.isEmpty
        } else {
            self.haveLyric = !music.lyric.isEmpty
        }
    }
    func loadLyric(music:YiMusic,translate:Bool) async {
        vm.parseError = nil
        do {
            try await vm.parseLyricsWithCustomAnimation(translate ? music.tlyric : music.lyric, duration: playerHolder.queryDuration())
            print("歌词加载完成")
        } catch {
            vm.parseError = error.localizedDescription
        }
    }
    enum ScrollType {
        //毫不迟疑直接无动画滚动
        case onLoad
        //迟疑一下再无动画滚动
        case onAppear
        //不迟疑、有动画滚动
        case withAnimation
    }
    func enableAutoScroll(_ type:ScrollType) {
        switch type {
        case .onLoad:
            //主动滚动一次，并且不需要动画（因为歌曲可能已经播放到一半）
            let time = playerHolder.currentTime()
            updateCurrentLyric(time: time, animation: nil,onLoad:true)
            //后续更新歌词滚动需要动画
            playerHolder.startToUpdateLyrics { time in
                Task { @MainActor in
                    updateCurrentLyric(time: time, animation: .easeOut,onLoad:false)
                }
            }
        case .onAppear:
            //主动滚动一次，并且不需要动画（因为歌曲可能已经播放到一半）
            let time = playerHolder.currentTime()
            updateCurrentLyric(time: time, animation: nil,onLoad:false)
            //后续更新歌词滚动需要动画
            playerHolder.startToUpdateLyrics { time in
                Task { @MainActor in
                    updateCurrentLyric(time: time, animation: .easeOut,onLoad:false)
                }
            }
        case .withAnimation:
            //主动滚动一次，并且需要动画
            let time = playerHolder.currentTime()
            updateCurrentLyric(time: time, animation: .easeOut)
            //后续更新歌词滚动需要动画
            playerHolder.startToUpdateLyrics { time in
                Task { @MainActor in
                    updateCurrentLyric(time: time, animation: .easeOut,onLoad:false)
                }
            }
        }
        
    }
    func disableAutoScroll() {
        playerHolder.stopUpdateLyrics()
        //页面都在TabView中划走了，利落一点，不然动画会残留到划回来的时候，导致冲突
        self.focusLyrics = nil
    }
    func updateCurrentLyric(time:CMTime,animation:Animation?,onLoad:Bool = true) {
        let matched:LyricsModel.LyricsLine? = vm.updateLineAtTime(date: playerHolder.currentTime())
        if let animation {
            print("触发有动画滚动")
            withAnimation(animation) {
                self.focusLyrics = matched
            }
        } else if onLoad {
            print("触发无动画滚动")
            self.focusLyrics = matched
        } else {
            //不能在页面刚onAppear时执行，不然会导致视图刷新时刷新。
            Task {
                try? await Task.sleep(nanoseconds:100000000)//0.1s
                print("触发延迟无动画滚动")
                await MainActor.run {
                    self.focusLyrics = matched
                }
            }
        }
    }
}

struct Zero3Delay<V:View>: View {
    var content:()->(V)
    @State
    private var showMe = false
    var body: some View {
        if showMe {
            content()
        } else {
            Rectangle()
                .frame(width: 1, height: 1, alignment: .center)
                .hidden()
                .task {
                    if showMe == false {
                        try? await Task.sleep(nanoseconds: 300000000)//0.3s
                        withAnimation(.smooth) {
                            showMe = true
                        }
                    }
                }
        }
    }
}



//每一行分离到一个显式的View，便于SwiftUI自己优化性能
struct LyricsLineView: View {
    var lyric:LyricsModel.LyricsLine
    @Binding
    var focusLyrics:LyricsModel.LyricsLine?
    @State
    var hightlight = false
    var body: some View {
        VStack(content: {
            if !lyric.content.isEmpty {
                Text(lyric.content)
                    .font(hightlight ? .title3 : .body)
                    .bold()
                    .foregroundStyle(hightlight ? .red : .primary)
            } else {
                Text("")
            }
        })
        //通过onChange而不是行内写条件表达式，实现更好的性能
        //placeHolder()是onChange不能应用与可选值的小补丁
        .onChange(of: focusLyrics ?? .placeHolder(), initial: true) { oldValue, newValue in
            var hightlightMe = false
            if oldValue != newValue {
                //计算是不是我
                if lyric.id == newValue.id {
                    hightlightMe = true
                }
            }
            withAnimation(.easeOut) {
                self.hightlight = hightlightMe
            }
        }
    }
}


import SwiftUI
import CoreMedia
import Combine
//这个类负责存储解析好的歌词，获取匹配当前时间点的歌词
@MainActor
@Observable
class LyricsViewModel {
    var parseError:String? = nil
    var parsedLyrics: [LyricsModel.LyricsLine] = []
    let actor = LyricsModel()
    func parseLyricsWithCustomAnimation(_ text:String,duration:CMTime) async {
        let result = await actor.parseLyrics(text, duration: duration)
        if self.parsedLyrics.isEmpty {
            self.parsedLyrics = result
        } else {
            withAnimation(.smooth) {
                self.parsedLyrics = result
            }
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
                    let timeRange = previousTime...(time - CMTime(seconds: 0.01, preferredTimescale: 600))
                    lyricsLines.append(LyricsLine(content: prevContent, time: timeRange))
                }
                previousTime = time
                previousContent = content
            }
        }
        
        // 处理最后一行的时间范围
        if let lastContent = previousContent {
            let lastRange = previousTime...duration
            lyricsLines.append(LyricsLine(content: lastContent, time: lastRange))
        }
        
        return lyricsLines
    }
}
