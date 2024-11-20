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
                    .onAppear {//这样在随机播放的时候，用户从NowPlay页划过来，也能直接看到当前正在播放的那首歌
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
    var music:YiMusicDetailedShell
    @State
    private var loadingError:ErrorPack? = nil
    @State
    private var hightlightMe = false
    var body: some View {
        MusicRowSingleLinePackForMusciPlayingListPageInner(musicDetailedShell: music)
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
            try await playerHolder.switchMusic(to: playerHolder.musicShellToRealObject(musicDetailedShell))
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
                LyricsViewSwitcher(isAutoScrolling: $isAutoScrolling)
                    .transition(.opacity)
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
