//
//  PlayListCachedPage.swift
//  TuneWave Watch App
//
//  Created by Yukun Li on 2024/7/23.
//

import SwiftUI
import SwiftData


@MainActor
@Observable
class CachedMusicOnlyRowModel {
    var isNetworkConnected:Bool? = nil
    var pushPage = false
    private let actor = NetworkToolKit()
    func checkNetworkConnect() {
        Task {
            self.isNetworkConnected = await actor.testNetworkConnectivityWithMinimalBandwidth()
        }
    }
    var loading = false
    var cachedSongs:[PlayListModel.PlayListSong]? = nil
    var updateCachedSongsError:String? = nil
    private let acotr = CachedMusicOnlyRowActor()
    func updateCachedSongs(allSongs:[PlayListModel.PlayListSong],modelContext: ModelContext) {
        Task {
            self.loading = true
            self.cachedSongs = nil
            do {
                //歌单中的歌曲
                let allSongID:[String] = allSongs.map({ song in
                    song.songID
                })
                //找到已经缓存的音乐中，有哪些是这个歌单的
                let predicate = #Predicate<YiMusic> { music in
                    allSongID.contains(music.musicID)
                }
                let fetchDescriptor = FetchDescriptor<YiMusic>(predicate: predicate)
                let allResult = try modelContext.fetch(fetchDescriptor)
                //转换本地音乐到在线音乐
                typealias TaskGroupType = PlayListModel.PlayListSong
                let cachedSongs: [TaskGroupType] = try await withThrowingTaskGroup(of: TaskGroupType.self) { group in
                    for music in allResult {
                        group.addTask {
                            return try await self.acotr.converte(music: music)
                        }
                    }
                    var taskGroupArray:[TaskGroupType] = []
                    for try await result in group {
                        taskGroupArray.append(result)
                    }
                    return taskGroupArray
                }
                //排序要与在线歌单内的保持一致
                var tempCachedSongs:[PlayListModel.PlayListSong] = []
                for songID in allSongID {
                    if let cachedSong = cachedSongs.first(where: { cachedSong in
                        cachedSong.songID == songID
                    }) {
                        tempCachedSongs.append(cachedSong)
                    }
                }
                withAnimation(.smooth) {
                    self.cachedSongs = tempCachedSongs
                }
            } catch {
                print("获取已缓存的音乐失败\(error.localizedDescription)")
                self.updateCachedSongsError = error.localizedDescription
            }
            self.loading = false
        }
 
    }
}

actor CachedMusicOnlyRowActor {
    func converte(music:YiMusic) throws -> PlayListModel.PlayListSong {
        .init(songID: music.musicID, name: music.name, artist: music.artist, imageURL: try music.albumImg.createTemporaryURL(extension: ""))
    }
}


struct CachedMusicOnly: View {
    @State
    var vm:CachedMusicOnlyRowModel
    var songs:[PlayListModel.PlayListSong]
    var body: some View {
        if let networkConnected = vm.isNetworkConnected {
            if !networkConnected {
                Button {
                    vm.pushPage = true
                } label: {
                    VStack(alignment: .leading) {
                        Text("Apple Watch没有联网")
                        Text("点此查看已缓存的音乐")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

            }
        }
    }
}

//本来想着是歌单列表里，把已经缓存的歌打上✅
//但是想着这样翻下去才能找好麻烦，而且翻到自己想听的发现没缓存就更伤心了
struct PlayListCachedMusicPage: View {
    @State
    var vm:CachedMusicOnlyRowModel
    var songs:[PlayListModel.PlayListSong]
    @Environment(\.modelContext)
    private var modelContext
    //未来还可以加个搜索功能
    var body: some View {
        VStack(content: {
            if !vm.loading {
                if let fetchedSongs = vm.cachedSongs {
                    if !fetchedSongs.isEmpty {
                        List {
                            VStack(alignment: .leading) {
                                Text("以下音乐已缓存，可在没网时播放")
                                Text("在本app内播放过的音乐即会被缓存")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            ForEach(fetchedSongs, content: { song in
                                MusicRowSingleLine(tapAction:{
                                    playMusic.send(.init(musicID: song.songID, name: song.name, artist: song.artist, coverImgURL: song.imageURL, playList: fetchedSongs))
                                },imageURL: song.imageURL, name: song.name)
                                //因为静默刷新，为了避免刷新的时候导致批量重载，我们需要显式添加id
                                .id(song.id)
                            })
                        }
                        .navigationTitle("已缓存")
                    } else {
                        ScrollViewOrNot {
                            VStack {
                                Text("还没有已缓存的音乐")
                                    .font(.headline)
                                Divider()
                                Text("在本app内播放过的音乐即会被缓存")
                                    .foregroundStyle(.secondary)
                                Text("您可以联网以后多播放几首音乐，它们就会被缓存下来，以供没网时播放")
                                    .foregroundStyle(.secondary)
                            }
                            .scenePadding(.horizontal)
                        }
                    }
                } else {
                    ErrorViewWithCustomTitle(title: "获取已缓存的音乐失败", errorText: vm.updateCachedSongsError ?? "未知错误")
                
                }
            } else {
                PlayListCachedMusicPageLoadingView()
            }
        })
            .onLoad {
                vm.updateCachedSongs(allSongs: songs, modelContext: modelContext)
            }
    }
}

struct PlayListCachedMusicPageLoadingView: View {
    @State
    private var showLine2 = false
    var body: some View {
        VStack {
            ProgressView()
                .onAppear {
                    showLine2 = true
                    //效果：如果2秒还没有加载出来，就显示“已缓存音乐较多，加载会更久”
                }
                .onDisappear {
                    showLine2 = false
                }
            if showLine2 {
                Text("已缓存音乐较多，加载会更久")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .transition(.opacity.animation(.smooth.delay(2)))
            }
        }
    }
}
