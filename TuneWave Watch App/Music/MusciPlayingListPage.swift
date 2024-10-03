//
//  MusciPlayingListPage.swift
//  TuneWave Watch App
//
//  Created by Yukun Li on 2024/7/31.
//

import SwiftUI

//当前正在播放的播放列表（不是歌单）
//播放列表只是歌单中已缓存的音乐
struct MusciPlayingListPage: View {
    @Environment(MusicPlayerHolder.self)
    private var playerHolder:MusicPlayerHolder
    
    @Environment(GoPlayListAndPickAMsuicAction.self)
    private var actionExcuter:GoPlayListAndPickAMsuicAction
    
    var body: some View {
        VStack {
            if playerHolder.playingList.isEmpty {
                ScrollViewOrNot {
                    VStack(content: {
                        Text("播放列表中还没有音乐")
                        Text("请前往歌单中任选一首音乐")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    })
                    .scenePadding(.horizontal)
                }
            } else {
                ScrollViewReader { proxy in
                    List {
                        Section("播放列表中共有\(playerHolder.playingList.count)首音乐", content: {
                          ForEach(playerHolder.playingList, content: { music in
                              MusicRowSingleLinePackForMusciPlayingListPage(music: music)
                                  .id(music.musicID)
                          })
                            Button("添加音乐", action: {
                                actionExcuter.startWorkFlow()
                            })
                        })
                    }
                    .listStyle(.elliptical)
                    .onAppear {
                        withAnimation(.easeOut) {
                            proxy.scrollTo(playerHolder.currentMusic?.musicID, anchor: .center)
                        }
                    }
                }
            }
        }
        .navigationTitle("播放列表")
    }
}


struct MusicRowSingleLinePackForMusciPlayingListPage: View {
    @Environment(MusicPlayerHolder.self)
    private var playerHolder:MusicPlayerHolder
    var music:YiMusicShell
    @State
    private var musicDetailedShell:YiMusicDetailedShell? = nil
    @State
    private var loadingError:ErrorPack? = nil
    @State
    private var hightlightMe = false
    var body: some View {
        Group {
            if let musicDetailedShell {
                MusicRowSingleLinePackForMusciPlayingListPageInner(musicDetailedShell: musicDetailedShell)
                    .transition(.blurReplace)
            } else if let loadingError {
                //此处ErrorView不需要在ScrollView中，是因为MusicRowSingleLinePackForMusciPlayingListPage本就在List里了
                ErrorView(errorText: loadingError.error.localizedDescription)
                    .transition(.blurReplace)
            } else {
                PlaceholderRow()
                    .transition(.blurReplace)
            }
        }
        .task {
            //看似这里把图片Data保存到硬盘再读取，但实际上降低了内存占用。本来要在内存中直接存储图片Data，但现在只有“write”的过程中会占内存，马上就释放了。
            do {
                loadingError = nil
                let realObject = try await playerHolder.musicShellToRealObject(music).toFullShell()
                guard !Task.isCancelled else { return }
                self.musicDetailedShell = realObject
            } catch {
                withAnimation(.smooth) {
                    loadingError = .init(error: error)
                }
            }
        }
    }
}

struct PlaceholderRow: View {
    var body: some View {
        MusicRowSingleLine(tapAction: { }, imageURL: .constant(nil), name: "",hightlight:.constant(false))
    }
}


struct MusicRowSingleLinePackForMusciPlayingListPageInner: View {
    @Environment(MusicPlayerHolder.self)
    private var playerHolder:MusicPlayerHolder
    var musicDetailedShell:YiMusicDetailedShell
    @State
    private var hightlightMe = false
    var body: some View {
        MusicRowSingleLine(tapAction: {
            try await playerHolder.switchMusic(to: playerHolder.musicShellToRealObject(musicDetailedShell.plainShell))
        }, imageURL: .constant(musicDetailedShell.albumImgURL), name: musicDetailedShell.name,hightlight:$hightlightMe)                              //正在播放的这首，高亮
        .onChange(of: playerHolder.currentMusic, initial: true, { oldValue, currentMusic in
            withAnimation(.smooth) {
                if musicDetailedShell.musicID == currentMusic?.musicID {
                    self.hightlightMe = true
                } else {
                    self.hightlightMe = false
                }
            }
        })
    }
}

//音乐数量多，页面初始化耗时，Lazy一下
struct MusciPlayingListPagePack: View {
    @State
    private var showRealPage = false
    var body: some View {
        VStack {
            if showRealPage {
                MusciPlayingListPage()
                    .transition(.blurReplace)
            } else {
                ProgressView()
                    .transition(.blurReplace)
            }
        }
        
        .onLoad {
            Task {
                try? await Task.sleep(for: .seconds(0.3))
                //延迟0.3秒加载，避免在页面slide入的动画过程中卡顿
                withAnimation(.easeIn) {
                    showRealPage = true
                }
            }
           
        }
    }
}

//首次打开页面需要渲染歌词ScrollView耗时，Lazy一下
struct LyricsViewPack: View {
    @Binding
    var isAutoScrolling:Bool
    @State
    private var showRealPage = false
    var body: some View {
        VStack {
            if showRealPage {
                LyricsView(isAutoScrolling: $isAutoScrolling)
                    .transition(.blurReplace)
            } else {
                ProgressView()
                    .transition(.blurReplace)
            }
        }
        
        .onLoad {
            Task {
                try? await Task.sleep(for: .seconds(0.3))
                //延迟0.3秒加载，避免在页面slide入的动画过程中卡顿
                withAnimation(.easeIn) {
                    showRealPage = true
                }
            }
           
        }
    }
}



@Observable
class GoPlayListAndPickAMsuicAction {
    var closePlayerCover:()->() = {
        print("未正确实现")
    }
    var openMyPlayListPage:()->() = {
        print("未正确实现")
    }
    var showPleasePickBanner = false
    func startWorkFlow() {
        Task {
            closePlayerCover()
            try? await Task.sleep(for: .seconds(0.3))
            openMyPlayListPage()
            try? await Task.sleep(for: .seconds(0.3))
            withAnimation(.smooth, {//可能在用户已经在歌单页面的时候触发，需要动画
                showPleasePickBanner = true//会在用户选了一首歌加入播放列表（也就是receive到let playMusic = PassthroughSubject<MusicPlayShip,Never>()时，设为false）。完成整个workflow
            })
        }
    }
}

#Preview {
    MusciPlayingListPage()
}
