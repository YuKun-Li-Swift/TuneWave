//
//  PlaylistMenu.swift
//  TuneWave
//
//  Created by Yukun Li on 2024/11/18.
//

import SwiftUI
import SwiftData


struct PlayListDetailActionsSheet: View {
    @State
    var vm:PlayListDetailPageModel
    @Environment(YiUserContainer.self)
    private
    var user:YiUserContainer
    @Environment(\.modelContext)
    private var modelContext
    var body: some View {
        NavigationStack {
            ScrollViewOrNot {
                VStack {
                    Button {
                        vm.showSearchPage = true
                    } label: {
                        Label("搜索", systemImage: "magnifyingglass")
                    }
                    .navigationDestination(isPresented: $vm.showSearchPage) {
                        PlayListDetailSearchPage(allSongs: $vm.data.songs)
                    }
                    if !vm.data.songs.isEmpty {
                        Button(action: {
                            Task {
                                vm.showMoreActionPage = false
                                try? await Task.sleep(for: .seconds(0.3))//0.3s，等自己所处的sheet先收回去
                                if let song = vm.data.songs.randomElement() {
                                    playMusic.send(.init(musicID: song.songID, name: song.name, artist: song.artist, coverImgURL: song.imageURL, playList: vm.data.songs))
                                } else {
                                    #if DEBUG
                                    fatalError("我也不知道出什么错了")
                                    #endif
                                }
                            }
                        }, label: {
                            Label("随机播放一首歌", systemImage: "shuffle")
                        })
                        .transition(.blurReplace.animation(.smooth))
                        
                        Button(action: {
                            vm.showBatchDownloadPage = true
                        }, label: {
                            Label("批量下载", systemImage: "square.and.arrow.down.on.square.fill")
                        })
                        .transition(.blurReplace.animation(.smooth))
                      
                    }
                    
                }
            }
            .navigationDestination(isPresented: $vm.showBatchDownloadPage) {
                BatchDownloadPack(playList: vm.data.songs, showMe: $vm.showBatchDownloadPage)
                    .environment(user)
            }
        }
    }
}
