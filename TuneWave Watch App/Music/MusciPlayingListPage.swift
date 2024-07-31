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
                              MusicRowSingleLine(tapAction: {
                                  try playerHolder.switchMusic(to: music)
                              }, imageURL: {
                                  do {
                                      return try music.albumImg.createTemporaryURL(extension: "")
                                  } catch {
                                      print("音乐封面图加载出错\(error.localizedDescription)")
                                      return nil
                                  }
                              }(), name: music.name,hightlight:(music.musicID == playerHolder.currentMusic?.musicID))                              //正在播放的这首，高亮
                              .id(music.musicID)
                          })
                            Button("添加音乐", action: {
                                actionExcuter.startWorkFlow()
                            })
                        })
                    }
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
            try? await Task.sleep(nanoseconds: 300000000)//0.3s
            openMyPlayListPage()
            try? await Task.sleep(nanoseconds: 300000000)//0.3s
            withAnimation(.smooth, {//可能在用户已经在歌单页面的时候触发，需要动画
                showPleasePickBanner = true//会在用户选了一首歌加入播放列表（也就是receive到let playMusic = PassthroughSubject<MusicPlayShip,Never>()时，设为false）。完成整个workflow
            })
        }
    }
}

#Preview {
    MusciPlayingListPage()
}
