//
//  LyricsView.swift
//  TuneWave Watch App
//
//  Created by Yukun Li on 2024/8/23.
//

import SwiftUI
import CoreMedia

@MainActor
struct LyricsView: View {
    @Environment(MusicPlayerHolder.self)
    var playerHolder:MusicPlayerHolder
    @State
    var vm = LyricsViewModelV1()
    @State
    var focusLyrics:LyricsModel.LyricsLine? = nil
    @Binding
    var isAutoScrolling:Bool
    @AppStorage("enableLyricsTranslate")
    var enableLyricsTranslate = false
    @State
    private var parsedLyric:[LyricsModel.LyricsLine] = []
    
    
    @State
    private var blurTransition = false
    
    @State
    var blurTransitionTask:Task<Void,Never>?
    
    @State
    private var rawLyric:String? = nil
    var body: some View {
        VStack {
            if let loadedLyrics = playerHolder.lyricsData {
                LyricsViewInner(parsedLyric: $parsedLyric,blurTransition:$blurTransition,rawLyric: $rawLyric,isAutoScrolling:$isAutoScrolling,  enableLyricsTranslate:$enableLyricsTranslate)
                    //为切换翻译开关做了动画
                    .onChange(of: enableLyricsTranslate, initial: false) { oldValue, newValue in
                            switchLyricSmooth()
                    }
                    .transition(.blurReplace.animation(.smooth))
            } else {
                Text("当前没有在播放的音乐")
                    .scenePadding(.horizontal)
                    .transition(.blurReplace.animation(.smooth))
            }
            
        }
        //页面初始化出来的歌词不需要有动画，就好像歌词一直在那儿一样
        .onLoad {
            switchLyricNoAnimation()
            switchRawLyricNoAnimation()
        }
        //为歌词页面打开时切歌做了动画
        .onChange(of: playerHolder.lyricsData, initial: false) { oldValue, newValue in
            switchLyricSmooth()
        }
    }
    //支持：从这首歌的parsedLyric切换到下一首歌的parsedLyrics
    //从这首歌的rawLyric切换到下一首歌的rawLyrics
    //从这首歌的parsedLyrics切换到下一首歌的rawLyrics
    //从这首歌的rawLyrics切换到下一首歌的parsedLyrics
    func switchLyricSmooth() {
        blurTransitionTask?.cancel()
        
        blurTransitionTask = Task {
            guard !Task.isCancelled else { return }
            withAnimation(.smooth(duration: 0.3)) {
                blurTransition = true
            }
            guard !Task.isCancelled else { return }
            try? await Task.sleep(for: .seconds(0.3))//先把动画做好了，此时歌词看不见了，再切换歌词
            guard !Task.isCancelled else { return }
            switchLyricNoAnimation()
            guard !Task.isCancelled else { return }
            switchRawLyricNoAnimation()
            guard !Task.isCancelled else { return }
            withAnimation(.smooth(duration: 0.3)) {
                blurTransition = false
            }
        }
    }
    func switchRawLyricNoAnimation() {
        rawLyric = {
            switch enableLyricsTranslate {
            case true:
                return playerHolder.currentMusic?.tlyric
            case false:
                return playerHolder.currentMusic?.lyric
            }
        }()
    }
    func switchLyricNoAnimation() {
        guard let loadedLyrics = playerHolder.lyricsData else {
            //此时会直接显示Text("当前没有在播放的音乐")
           return
        }
        if enableLyricsTranslate {
            parsedLyric = loadedLyrics.parsedTranslateLyrics
        } else {
            parsedLyric = loadedLyrics.parsedLyrics
        }
    }
}


@MainActor
struct LyricsViewInner: View {
    @Binding
    var parsedLyric:[LyricsModel.LyricsLine]
    @Binding
    var blurTransition:Bool
    @Environment(MusicPlayerHolder.self)
    var playerHolder:MusicPlayerHolder
    @Binding
    var rawLyric:String?
    @State
    var focusLyrics:LyricsModel.LyricsLine? = nil
    @State
    var vm = LyricsViewModelV1()
    @Binding
    var isAutoScrolling:Bool
    @Binding
    var enableLyricsTranslate:Bool
    var body: some View {
        VStack {
            //在常亮状态下，要求30帧刷新歌词。否则会停止滚动（静止在一行）。
            //常见：写作业，手表戴在手腕上，想看滚动歌词的时候瞟一眼。
            //骑车听歌，想看歌词的时候瞟一眼。
            ZStack(content: {
                Rectangle()
                //占位，填充满整个页面，即便歌词只有一行或两行
                    .fill(Color.clear)
                
                if parsedLyric.isEmpty {
                    //歌词不是空的，但是解析出来是空的（可能是未正确解析）
                    //说明解析出来的歌词确实是空的，那就显示原始歌词（未解析的）
                    LyricUnormalView(rawLyric: $rawLyric,blurTransition:$blurTransition, enableLyricsTranslate: $enableLyricsTranslate)
                } else {
                    TimelineView(.periodic(from: .now, by: 1/30), content: { _ in
                        VStack {
                            ScrollView(.vertical) {
                                VStack(alignment: .leading,spacing:23.3) {
                                    ForEach(parsedLyric) { lyric in
                                        LyricsLineView(lyric: lyric,focusLyrics:$focusLyrics)
                                            .blur(radius: blurTransition ? 30 : 0)
                                            .opacity(blurTransition ? 0.5 : 1)
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
                    
                }
            })
            
            .navigationTitle("歌词")
            .onAppear {
                //歌词页面打开需要主动滚动一次
                Task {
                    //ScrollView不能在刚渲染出来就去滚动，无反应
                    try? await Task.sleep(for: .seconds(0.1))
                    enableAutoScroll(.onLoad,isEnable: isAutoScrolling)
                }
            }
            .onDisappear {
                disableAutoScroll()
            }
            .onChange(of: isAutoScrolling, initial: false) {  oldValue, newValue in
                if newValue {
                    //isAutoScrolling打开时需要主动滚动一次（此时歌词在的，需要有动画）
                    enableAutoScroll(.withAnimation,isEnable: newValue)
                } else {
                    disableAutoScroll()
                }
            }
            .onChange(of: parsedLyric, initial: false, { oldValue, newValue in
                //后续因为切换了翻译而造成歌词重新切换，或者就在这个页面开着的时候因为切歌而切换了歌词，需要无动画滚动
                Task {//不能在同一帧做
                    //歌词切换完成需要主动滚动一次，但是不用延迟
                    enableAutoScroll(.onLoad,isEnable: isAutoScrolling)
                }
            })
        }
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                Rectangle()
                    .frame(width: 1, height: 1, alignment: .center)
                    .hidden()
                Rectangle()
                    .frame(width: 1, height: 1, alignment: .center)
                    .hidden()
                LightToolbarButton(symbolName: "translate", accessbilityLabel: enableLyricsTranslate ? "查看歌词原文" : "查看歌词翻译") {
                    enableLyricsTranslate.toggle()
                }
            }
        }
        .animation(.smooth, value: enableLyricsTranslate)
        
    }
    enum ScrollType {
        //毫不迟疑直接无动画滚动
        case onLoad
        //迟疑一下再无动画滚动
        case onAppear
        //不迟疑、有动画滚动
        case withAnimation
    }
    func enableAutoScroll(_ type:ScrollType,isEnable:Bool) {
        if isEnable {
            switch type {
            case .onLoad,.onAppear:
                //主动滚动一次，并且不需要动画（因为歌曲可能已经播放到一半）
                let time = playerHolder.currentTime()
                updateCurrentLyric(time: time, animation: nil)
                //后续更新歌词滚动需要动画
                playerHolder.startToUpdateLyrics { time in
                    Task { @MainActor in
                        updateCurrentLyric(time: time, animation: .easeOut)
                    }
                }
            case .withAnimation:
                //主动滚动一次，并且需要动画
                let time = playerHolder.currentTime()
                updateCurrentLyric(time: time, animation: .easeOut)
                //后续更新歌词滚动需要动画
                playerHolder.startToUpdateLyrics { time in
                    Task { @MainActor in
                        updateCurrentLyric(time: time, animation: .easeOut)
                    }
                }
            }
        }
        
    }
    @State
    private var noParsedLyric = false
    func getParsedLyric() throws -> [LyricsModel.LyricsLine] {
        noParsedLyric = false
        if let pack = playerHolder.lyricsData {
            if enableLyricsTranslate {
                return pack.parsedTranslateLyrics
            } else {
                return pack.parsedLyrics
            }
        } else {
            noParsedLyric = true
            throw NoCurrentMusicError.noCurrentMusic
        }
    }
    enum NoCurrentMusicError:Error,LocalizedError {
        case noCurrentMusic
    }
    func disableAutoScroll() {
        playerHolder.stopUpdateLyrics()
        //页面都在TabView中划走了，利落一点，不然动画会残留到划回来的时候，导致冲突
        self.focusLyrics = nil
    }
    func updateCurrentLyric(time:CMTime,animation:Animation?) {
        do {
            let matched:LyricsModel.LyricsLine? = vm.updateLineAtTime(date: playerHolder.currentTime(), parsedLyrics: try getParsedLyric())
            if let animation {
                //            print("触发有动画滚动")
                withAnimation(animation) {
                    self.focusLyrics = matched
                }
            } else {
                //不能在页面刚onAppear时执行，不然会导致视图刷新时刷新。
                Task {
                    self.focusLyrics = nil//在由翻译歌词切换到原词的时候，需要先设为nil再设置为matched才能有效果。
                    try? await Task.sleep(for: .seconds(0.1))
                    print("触发延迟无动画滚动")
                    self.focusLyrics = matched
                }
            }
        } catch {
            //会在内部的throws中处理
        }
    }
}


struct LyricUnormalView: View {
    @Binding
    var rawLyric:String?
    @Binding
    var blurTransition:Bool
    @Binding
    var enableLyricsTranslate:Bool
    var body: some View {
        VStack(content: {
            if let rawLyric,!rawLyric.isEmpty {
                ScrollViewOrNot {
                    Text(rawLyric)
                        .scenePadding(.horizontal)
                }
                .blur(radius: blurTransition ? 30 : 0)
                .opacity(blurTransition ? 0.5 : 1)
            } else {
                Text(enableLyricsTranslate ? "这首歌没有翻译歌词" : "这首歌没有歌词")
                    .contentTransition(.numericText())
                    .blur(radius: blurTransition ? 30 : 0)
                    .opacity(blurTransition ? 0.5 : 1)
            }
        })
    }
}

//每一行分离到一个显式的View，便于SwiftUI自己优化性能
struct LyricsLineView: View {
    var lyric:LyricsModel.LyricsLine
    @Binding
    var focusLyrics:LyricsModel.LyricsLine?
    @State
    private var hightlight = false
    @Environment(\.isLuminanceReduced)
    private var isLuminanceReduced
    @State
    private var textColor:Color = .primary
    var body: some View {
        VStack(content: {
            if !lyric.content.isEmpty {
                Text(lyric.content)
                    .font(hightlight ? .title3 : .body)
                    .bold()
                    .foregroundStyle(textColor)
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
        .onChange(of: hightlight, initial: true) {
            updateTextColor()
        }
        .onChange(of: isLuminanceReduced, initial: true) {
            updateTextColor()
        }
    }
    func updateTextColor() {
        withAnimation(.smooth) {
            if !isLuminanceReduced {
                //亮屏时
                if hightlight {
                    self.textColor = .red
                } else {
                    self.textColor = .primary
                }
            } else {
                //放下手腕时
                if hightlight {
                    //放下手腕时，暗红色的文字很难在黑色背景中被辨认，此时白色文字才是可读性最好的
                    self.textColor = .primary
                } else {
                    self.textColor = .secondary
                }
            }
        }
    }
}
