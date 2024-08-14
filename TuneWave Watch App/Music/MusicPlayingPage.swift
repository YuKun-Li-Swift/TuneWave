//
//  MusicPlayingPage.swift
//  TuneWave Watch App
//
//  Created by Yukun Li on 2024/7/16.
//

import SwiftUI

import WatchKit
struct NowPlayView: View {
    enum Page {
        case playingListPage
        case nowPlayPage
        case lyricsPage
    }
    var dismissMe:()->()
    @Environment(MusicPlayerHolder.self)
    var playerHolder:MusicPlayerHolder
    @State
    private var selectedTab = Page.nowPlayPage
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
    @State
    private var showInformation = false
    var body: some View {
        
        ZStack {
            VStack {
                
                
                VStack(content: {
                    TabView(selection: $selectedTab, content: {
                        MusciPlayingListPagePack()
                            .tag(Page.playingListPage)
                        NowPlayingView()
                            .tag(Page.nowPlayPage)
                        LyricsView(isAutoScrolling: $isAutoScrolling)
                            .tag(Page.lyricsPage)
                    })
                })
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        switch selectedTab {
                        case .playingListPage:
                            EmptyView()
                        case .nowPlayPage:
                            Button {
                                showMorePage = true
                            } label: {
                                Label("更多操作", systemImage: "ellipsis")
                            }
                        case .lyricsPage:
                            Button {
                                withAnimation(.easeOut) {
                                    isAutoScrolling.toggle()
                                }
                            } label: {
                                Label(isAutoScrolling ? "点此关闭歌词自动滚动" : "点此打开歌词自动滚动", systemImage: "digitalcrown.arrow.counterclockwise.fill")
                                    .transition(.blurReplace)
                            }
                        }
                    }
                }
                .navigationDestination(isPresented: $showMorePage, destination: {
                    NowPlayMoreActionPage(dismissMe: {
                        showMorePage = false
                        dismissMe()
                    },showPlayingListPage:{
                        slideToPage(.playingListPage)
                    }, showLyricPage: {
                        slideToPage(.lyricsPage)
                    })
                })
                
                .onReceive(errorCheckTimer, perform: { _ in
                    playerHolder.updateError()
                })
                
                .modifier(ShowAutoScrollTip(isAutoScrolling: isAutoScrolling, showTip: showTip))
                
            }
            .opacity(showInformation ? 0 : 1)
            .allowsHitTesting(showInformation ? false : true)
            
            AutoScrollTipView(isAutoScrolling:$isAutoScrolling,showAutoScrollTip: $showAutoScrollTip)
            
            VStack {
                if showInformation {
                    //优先显示错误信息
                    if !playerHolder.playingError.isEmpty {
                        ScrollViewOrNot {
                            ErrorView(errorText: playerHolder.playingError)
                        }
                    } else if !playerHolder.waitingPlayingReason.isEmpty {
                        ScrollViewOrNot {
                            VStack {
                                Text("即将开始播放")
                                    .font(.headline)
                                Divider()
                                Text(playerHolder.waitingPlayingReason)
                                    .foregroundStyle(.secondary)
                            }
                            .transition(.blurReplace)
                        }
                    }
                    
                }
            }
        }
        .onAppear {
            //在第三方app中播放过别的内容，再切回这里，NowPlay会停留在第三方app的内容，需要主动刷新一下。
            playerHolder.updateNowPlay()
        }
        .animation(.smooth, value: showInformation)
        .onChange(of: playerHolder.playingError, initial: true) { oldValue, newValue in
            updateShowInformation()
        }
        .onChange(of: playerHolder.waitingPlayingReason, initial: true) { oldValue, newValue in
            updateShowInformation()
        }
    }
    func updateShowInformation() {
        if playerHolder.playingError.isEmpty && playerHolder.waitingPlayingReason.isEmpty {
            self.showInformation = false
        } else {
            self.showInformation = true
        }
    }
    func slideToPage(_ page:Page) {
        showMorePage = false
        Task {
            //等待页面关闭的动画完成，不然Tab切换没效果
            try? await Task.sleep(nanoseconds:300000000)//0.3s
            withAnimation(.smooth) {
                selectedTab = page
            }
        }
    }
}

struct NowPlayMoreActionPage: View {
    var dismissMe:()->()
    @State
    private var tutorialFailed = false
    @State
    private var haptic = UUID()
    @State
    private var showNeedMoreMusicAlert = false
    @Environment(MusicPlayerHolder.self)
    private var playerHolder:MusicPlayerHolder
    @State
    private var enlargeButton = false
    var showPlayingListPage:()->()
    var showLyricPage:()->()
    var body: some View {
        ScrollViewOrNot {
            VStack {
                @Bindable var playerHolderBinding = playerHolder
                TuneWavePicker(selected: $playerHolderBinding.playingMode, showNeedMoreMusicAlert: $showNeedMoreMusicAlert,playerHolder:playerHolder)
                Button(action: {
                    showPlayingListPage()
                }, label: {
                    Label("播放列表", systemImage: "music.note.list")
                        .symbolEffect(.pulse, options: .repeating)
                })
                .scaleEffect(x: enlargeButton ? 2 : 1, y: enlargeButton ? 2 : 1, anchor: .bottom)
                Button(action: {
                    showLyricPage()
                }, label: {
                    Label("查看歌词", systemImage: "note.text")
                        .symbolEffect(.pulse, options: .repeating)
                })
                Button(action: {
                    //触发触感，告诉用户是点到了的，因为接下来的动画可能让人迷惑
                    haptic = UUID()
                    dismissMe()
                    Task {
                        //需要等待sheet关闭的动画完成，否则会无法正确弹出视频
                        try? await Task.sleep(nanoseconds: 3000000000)//0.3s
                        playTutorialVideo()
                    }
                }, label: {
                    Label("调节音量", systemImage: "volume.3.fill")
                        .symbolEffect(.pulse, options: .repeating)
                })
                .sensoryFeedback(.impact, trigger: haptic)
              
                
            }
            .alert("调节音量教程视频播放失败，"+DeveloperContactGenerator.generate(), isPresented: $tutorialFailed, actions: {})
            .alert("当前播放列表中只有一首歌，只能单曲循环，请先查看您的播放列表", isPresented: $showNeedMoreMusicAlert, actions: {
                Button("我去看看", action: {
                    focusToPlayListButton()
                })
            })
            
        }
    }
    func focusToPlayListButton() {
        withAnimation(.smooth.delay(0.5)) {
                enlargeButton = true
            } completion: {
                Task {
                    try? await Task.sleep(nanoseconds: 200000000)//0.2s
                    withAnimation(.smooth) {
                        enlargeButton = false
                    }
                }
            }
    }
    func playTutorialVideo() {
        //没声音的视频，可以直接开始播放
        WKExtension.shared().visibleInterfaceController?.presentMediaPlayerController(with: Bundle.main.url(forResource: "ChangeVolumeVideo", withExtension: "mp4")!, options: [WKMediaPlayerControllerOptionsAutoplayKey:true,WKMediaPlayerControllerOptionsVideoGravityKey:WKVideoGravity.resizeAspect.rawValue,WKMediaPlayerControllerOptionsLoopsKey:true], completion: { _, _, error in
            if error != nil {
                self.tutorialFailed = true
            }
        })
    }
}

//原生的Picker会出现背景毛玻璃丢失、返回按钮消失的问题。
struct TuneWavePicker: View {
    @Binding
    var selected:PlayingMode
    @Binding
    var showNeedMoreMusicAlert:Bool
    @State
    var playerHolder:MusicPlayerHolder
    @State
    private var showSheet = false
    var body: some View {
        Button {
            showSheet = true
        } label: {
            VStack(alignment: .leading, content: {
                Text("当前播放模式")
                Text(selected.humanReadbleName())
                    .contentTransition(.numericText())
                    .foregroundStyle(.secondary)
                    .font(.footnote)
            })
        }
        .navigationDestination(isPresented: $showSheet, destination: {
            List {
                Button(action: {
                    itemPicked(PlayingMode.singleLoop, name: "单曲循环", needMoreThanOneSong: false)
                }, label: {
                    HStack(content: {
                        Text("单曲循环")
                        Spacer()
                        if selected == PlayingMode.singleLoop {
                            Image(systemName: "checkmark")
                        }
                    })
                })
                
                Button(action: {
                    itemPicked(PlayingMode.playingListLoop, name:"顺序播放", needMoreThanOneSong: true)
                }, label: {
                    HStack(content: {
                        Text("顺序播放")
                        Spacer()
                        if selected == PlayingMode.playingListLoop {
                            Image(systemName: "checkmark")
                        }
                    })
                })
                Button(action: {
                    itemPicked(PlayingMode.random, name: "随机", needMoreThanOneSong: true)
                }, label: {
                    
                    HStack(content: {
                        Text("随机")
                        Spacer()
                        if selected == PlayingMode.random {
                            Image(systemName: "checkmark")
                        }
                    })
                })
            }
            .listStyle(.carousel)
            .navigationTitle("播放模式")
        })
    }
    func itemPicked(_ item:PlayingMode,name:String,needMoreThanOneSong:Bool) {
        showSheet = false
        if needMoreThanOneSong && (playerHolder.playingList.count <= 1) {
            showNeedMoreMusicAlert = true
            //拒绝切换，跳到单曲循环
            withAnimation(.smooth) {
                selected = .singleLoop
            }
        } else {
            withAnimation(.smooth) {
                self.selected = item
            }
        }
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
    @State
    var rawLyric:String? = nil
    @Namespace
    var nameSpace
    var body: some View {
        VStack {
            if let music = playerHolder.currentMusic {
                if music.musicID == vm.currentShowingLyricBelongMuic {
                    VStack {
                        if haveLyric {
                            //在常亮状态下，要求30帧刷新歌词。否则会停止滚动（静止在一行）。
                            //常见：写作业，手表戴在手腕上，想看滚动歌词的时候瞟一眼。
                            //骑车听歌，想看歌词的时候瞟一眼。
                            ZStack(content: {
                                Rectangle()
                                //占位，填充满整个页面，即便歌词只有一行或两行
                                    .fill(Color.clear)
                                
                                if vm.parsedLyrics.isEmpty {
                                    //歌词不是空的，但是解析出来是空的（可能是未正确解析）
                                    //说明解析出来的歌词确实是空的，那就显示原始歌词（未解析的）
                                    LyricUnormalView(rawLyric: $rawLyric)
                                } else {
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
                                }
                            })
                            
                            .navigationTitle("歌词")
                           
                            .onAppear {
                                //因为页面不在屏幕上的时候，是不更新歌词位置以省电的，因此页面onAppear需要主动无动画滚动一次
                                enableAutoScroll(.onAppear,isEnable: isAutoScrolling)
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
                            .transition(.blurReplace)
                        } else {
                            //确保这行字总是居中，而不会乱飘
                           Rectangle()
                                .fill(Color.clear)
                                .overlay(alignment: .center) {
                                    Text(enableLyricsTranslate ? "这首音乐没有歌词翻译" : "这首音乐没有歌词")
                                        .contentTransition(.numericText()) //在两个状态之间切换的时候，有连贯的动画效果
                                        .animation(.smooth, value: enableLyricsTranslate)//似乎在外层放的enableLyricsTranslate的animation对这里的numericText无效
                                }
                        }
                    }
                    
                    .onChange(of: enableLyricsTranslate, initial: false) { oldValue, newValue in
                        //重新加载歌词+重新滚动
                        Task {
                            await loadLyric(music: music, translate: newValue, animation: .smooth)
                            //歌词加载完成需要主动滚动一次，但是不用延迟
                            enableAutoScroll(.onLoad,isEnable: isAutoScrolling)
                        }
                    }
                    .transition(.blurReplace)
                } else {
                    ProgressView()
                        .onAppear {
                            Task {
                                if vm.currentShowingLyricBelongMuic.isEmpty {
                                    //是页面打开的歌词加载，此时不需要动画，感觉就像歌词一直在这儿，没有重新加载过
                                    await loadLyric(music: music, translate: enableLyricsTranslate,animation: nil)
                                    //歌词加载完成需要主动滚动一次
                                    Task {//产生一帧的等待，让ScrollView绘制出来
                                        //然后无动画立即更新滚动位置
                                        enableAutoScroll(.onLoad,isEnable: isAutoScrolling)
                                    }
                                } else {
                                    //切歌的歌词加载，需要动画
                                    await loadLyric(music: music, translate: enableLyricsTranslate,animation: .smooth)
                                    //歌词加载完成不需要滚动，因为结果这一波页面切换，本来ScrollView就在最顶上了
                                }
                            }
                        }
                        .transition(.blurReplace)
                }
                
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
                LightToolbarButton(symbolName: "translate", accessbilityLabel: enableLyricsTranslate ? "查看歌词原文" : "查看歌词翻译") {
                    enableLyricsTranslate.toggle()
                }
            }
        }
        .animation(.smooth, value: playerHolder.currentMusic)
        .animation(.smooth, value: enableLyricsTranslate)
        .animation(.smooth, value: haveLyric)
    }
    func updateHaveLyricState(music:YiMusic) {
        if self.enableLyricsTranslate {
            self.rawLyric = music.tlyric
            self.haveLyric = !music.tlyric.isEmpty
        } else {
            self.rawLyric = music.lyric
            self.haveLyric = !music.lyric.isEmpty
        }
    }
    func loadLyric(music:YiMusic,translate:Bool,animation:Animation?) async {
        vm.parseError = nil
        do {
            withAnimation(animation) {
                updateHaveLyricState(music: music)
            }
            try await vm.parseLyricsWithCustomAnimation(translate ? music.tlyric : music.lyric, musicDuration: playerHolder.queryDuration(),animation: animation)
            withAnimation(animation) {
                vm.currentShowingLyricBelongMuic = music.musicID
            }
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
    func enableAutoScroll(_ type:ScrollType,isEnable:Bool) {
        if isEnable {
            switch type {
            case .onLoad,.onAppear:
                //主动滚动一次，并且不需要动画（因为歌曲可能已经播放到一半）
                let time = playerHolder.currentTime()
                updateCurrentLyric(time: time, animation: nil,onLoad:true)
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
        
    }
    func disableAutoScroll() {
        playerHolder.stopUpdateLyrics()
        //页面都在TabView中划走了，利落一点，不然动画会残留到划回来的时候，导致冲突
        self.focusLyrics = nil
    }
    func updateCurrentLyric(time:CMTime,animation:Animation?,onLoad:Bool = true) {
        let matched:LyricsModel.LyricsLine? = vm.updateLineAtTime(date: playerHolder.currentTime())
        if let animation {
            //            print("触发有动画滚动")
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

struct LyricUnormalView: View {
    @Binding
    var rawLyric:String?
    @State
    var rawLyricCopy:String? = nil
    @State
    var changeCount = 0
    var body: some View {
        VStack(content: {
            if let rawLyricCopy {
                ScrollViewOrNot {
                    Text(rawLyricCopy)
                        .scenePadding(.horizontal)
                }
            } else {
                Text("歌词为空")
            }
        })
        .onAppear {
            //不要直接使用传入的rawLyric，因为在视图即将消失的时候，传入的rawLyric已经变成新的歌词了（这会导致闪烁），但实际上我们还是希望它保持旧的的，所以我们在视图onAppear的时候copy一份
            self.rawLyricCopy = rawLyric
        }
        .onChange(of: rawLyric, initial: false) { _, newValue in
            changeCount += 1
            if changeCount >= 2 {
#if DEBUG
                fatalError("这不应该发生，调查一下")
#endif
            } else {
                //会在视图即将消失前变成新的歌词，使changeCount = 1
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
                        print("0.3秒之期已到！")
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
        
        return lyricsLines
    }
}
