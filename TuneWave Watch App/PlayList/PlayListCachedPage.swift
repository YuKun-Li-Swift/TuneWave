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
//#if DEBUG
//            self.isNetworkConnected = false
//#else
            self.isNetworkConnected = await actor.testNetworkConnectivityWithMinimalBandwidth()
//#endif
        }
    }
    var loading = false
    var cachedSongs:[YiMusicDetailedShell]? = nil
    var updateCachedSongsError:String? = nil
    private let acotr = CachedMusicOnlyRowActor()
    
    private
    func getAllCachedMusic(allSongID:[String],modelContext:ModelContext) async throws -> [YiMusicDetailedShell] {
        try await PersistentModel.fetchFromDBVersionC(predicate: #Predicate<YiMusic> { music in
            allSongID.contains(music.musicID)//本地音乐中是这个歌单里的音乐
        }, sortBy: { _,_ in
            true/*顺序没有意义，后面还要二次按照歌单中的顺序排序的*/
        }, modelContext: modelContext)
    }
    
    func updateCachedSongs(allSongs:[PlayListModel.PlayListSong],modelContext: ModelContext) {
        //在初始化类的时候，loading = false
        //这里loading = true不要带动画，因为接下来的操作会占用主线程，这里不带动画，配合一会儿切换到Task的一个RunLoop的时间，足以让ProgressView呈现出来了。
        self.loading = true
        Task {
            self.cachedSongs = nil
            do {
                //歌单中的歌曲
                let allMusicID:[String] = allSongs.map { song in
                    song.songID
                }
                //本地音乐中是这个歌单里的音乐
                let cachedMusics = try await getAllCachedMusic(allSongID: allMusicID, modelContext: modelContext)
                //排序要与在线歌单内的保持一致
                self.cachedSongs = YiMusicDetailedShell.sortTo(existMusics: cachedMusics, targetOrder: allMusicID)
            } catch {
                print("获取已缓存的音乐失败\(error.localizedDescription)")
                self.updateCachedSongsError = error.localizedDescription
            }
            //这里的loading = false要带动画，以便看到丝滑的从ProgressView过渡到List的效果。
            withAnimation(.smooth) {
                self.loading = false
            }
        }
        
    }
}

actor CachedMusicOnlyRowActor {
    func converte(music:YiMusic) throws -> PlayListModel.PlayListSong {
        .init(songID: music.musicID, name: music.name, artist: music.artist, imageURL: try music.albumImg.createTemporaryURL(extension: nil))
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
    var playListMusics:[PlayListModel.PlayListSong]
    @Environment(\.modelContext)
    private var modelContext
    @Environment(MusicPlayerHolder.self)
    private var musicHolder
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
                            ForEach(fetchedSongs, content: { myMusic in
                                MusicRowSingleLine(tapAction: {
                                    let song = try myMusic.toAliveMusic(playerHolder: musicHolder)//因为artist字段需要从YiMusic身上取
                                    playMusic.send(.init(musicID: myMusic.musicID, name: myMusic.name, artist: song.artist, coverImgURL: myMusic.albumImgURL, playList: playListMusics))
                                }, imageURL: .constant(myMusic.albumImgURL), name: myMusic.name,hightlight:.constant(false))
                                //因为静默刷新，为了避免刷新的时候导致批量重载，我们需要显式添加id
                                .id(myMusic.id)
                            })
                        }
                        .navigationTitle("已缓存")
                        .transition(.blurReplace)
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
                        .transition(.blurReplace.animation(.smooth))
                    }
                } else {
                    ErrorViewWithCustomTitle(title: "获取已缓存的音乐失败", errorText: vm.updateCachedSongsError ?? "未知错误")
                        .transition(.blurReplace.animation(.smooth))
                }
            } else {
                PlayListCachedMusicPageLoadingView()
                    .transition(.blurReplace)
            }
        })
        .onLoad {
            vm.updateCachedSongs(allSongs: playListMusics, modelContext: modelContext)
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
