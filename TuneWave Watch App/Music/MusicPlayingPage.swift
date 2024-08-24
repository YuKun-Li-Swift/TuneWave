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
                .onLoad {
                    Task {
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
}





