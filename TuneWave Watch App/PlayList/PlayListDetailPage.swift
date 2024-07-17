//
//  PlayListDetailPgae.swift
//  TuneWave Watch App
//
//  Created by Yukun Li on 2024/7/11.
//

import SwiftUI

struct PlayListDetailPage: View {
    var playList:PlayListModel.PlayListObj
    @State
    var vm:PlayListDetailPageModel?
    @State
    var reqMod = PlayListModel()
    
    var body: some View {
        LoadingSkelton {
            PlayListDetailLoadingView()
        } successView: {
            VStack {
                if let vm {
                    PlayListDetailList(vm: vm) {
                        let result = try await reqMod.getPlaylistDetail(playlist: playList,useCache: false)
                        let newVM = PlayListDetailPageModel(data: result.0, haveMore: result.1)
                        Task { @MainActor in
                            if !Task.isCancelled {
                                self.vm = newVM
                            }
                        }
                    }
                    .id(vm)
                } else {
                    NeverErrorView(remoteControlTag: "playListDetailPageNeverError")
                }
            }
        } errorView: { error in
            APIErrorDisplay(remoteControlTag: "playListDetailPage", error: error)
        } loadingAction: {
            let result =  try await reqMod.getPlaylistDetail(playlist: playList,useCache: true)
            let newVM = PlayListDetailPageModel(data:result.0, haveMore: result.1)
            self.vm = newVM
        }
        .navigationTitle(playList.name)
    }
}

struct PlayListDetailLoadingView: View {
    @State
    var showLine2 = false
    var body: some View {
        VStack {
            ProgressView()
                .onAppear {
                    showLine2 = true
                    //效果：如果5秒还没有加载出来，就显示“歌单内歌曲较多，加载会更久”
                }
                .onDisappear {
                    showLine2 = false
                }
            if showLine2 {
                Text("歌单内歌曲较多，加载会更久")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .transition(.opacity.animation(.smooth.delay(5)))
            }
        }
    }
}


struct PlayListDetailList: View {
    @State
    var vm:PlayListDetailPageModel
    @State
    private var showReloadingAlert = false
    @State
    private var showReloadingFailAlert = false
    @State
    private var reloadingFail:Error? = nil
    @State
    private var reloadTask:Task<(), Never>?
    @State
    private var showSearchPage = false
    //忽略缓存
    var focrceReload:() async throws -> ()
    var body: some View {
        VStack {
            if vm.data.songs.isEmpty {
                NoMusicInPlayList()
            } else {
                List {
                    if vm.haveMore {
                        PlayListDetailListHaveMoreBanner()
                    }
                    ForEach(vm.data.songs) { song in
                        MusicRowSingleLine(tapAction:{
                            playMusic.send(.init(musicID: song.songID, name: song.name, artist: song.artist, converImgURL: song.imageURL))
                        },imageURL: song.imageURL, name: song.name)
                    }
                }
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
                    showReloadingAlert = true
                    reloadTask = Task {
                        reloadingFail = nil
                        do {
                            try await focrceReload()
                            showReloadingAlert = false
                        } catch {
                            showReloadingAlert = false
                            reloadingFail = error
                            showReloadingFailAlert = true
                        }
                    }
                } label: {
                    Label("刷新", systemImage: "arrow.triangle.2.circlepath")
                }
                
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    showSearchPage = true
                } label: {
                    Label("搜索", systemImage: "magnifyingglass")
                }
            }
        }
        .sheet(isPresented: $showReloadingAlert, content: {
            ViewThatFits {
                ForceReloadAlertContent()
                ScrollView {
                    ForceReloadAlertContent()
                }
            }.toolbar {
                ToolbarItemGroup(placement: .cancellationAction) {
                    Button {
                        reloadTask?.cancel()
                    } label: {
                        Label("取消", systemImage: "chevron.backward")
                    }
                    
                }
            }
        })
        .sheet(isPresented: $showSearchPage, content: {
            PlayListDetailSearchPage(allSongs: $vm.data.songs)
        })
        .alert({
            if let e = reloadingFail {
                return "出错了：\n" + e.localizedDescription
            } else {
                return "未知错误"
            }
        }(), isPresented: $showReloadingFailAlert, actions: {
            
        })
    }
}
struct PlayListDetailListHaveMoreBanner: View {
    var body: some View {
        VStack(alignment: .leading) {
            Text("歌单内还有更多歌曲，但受限于性能原因，暂不显示。")
            Label("建议您为Apple Watch单独创建一个小歌单。", systemImage: "lightbulb.fill")
        }
        .font(.footnote)
    }
}


struct PlayListDetailSearchPage: View {
    @Binding
    var allSongs:[PlayListModel.PlayListSong]
    @State
    private var keyword = ""
    @State
    var showSearchResultPage = false
    var body: some View {
        NavigationStack {
            VStack {
                TextField("输入搜索关键词", text: $keyword)
                    .onSubmit {
                        goSearch()
                    }
                Button("搜索") {
                    goSearch()
                }
                .buttonStyle(.borderedProminent)
            }
            .navigationDestination(isPresented: $showSearchResultPage, destination: {
                PlayListDetailSearchResultPage(allSongs: $allSongs, keyword: $keyword)
            })
            .navigationTitle("搜索")
        }
    }
    func goSearch() {
        if !keyword.isEmpty {
            showSearchResultPage = true
        }
    }
}

struct PlayListDetailSearchResultPage: View {
    @Binding
    var allSongs:[PlayListModel.PlayListSong]
    @Binding
    var keyword:String
    @State
    var vm = PlayListDetailSearchModel()
    var body: some View {
        VStack {
            if !vm.searching {
                if vm.searchedRes.isEmpty {
                    PlayListDetailSearchNotFound(keyword: keyword)
                } else {
                    List {
                        ForEach(vm.searchedRes) { song in
                            MusicRowSingleLine(tapAction:{
                                playMusic.send(.init(musicID: song.songID, name: song.name, artist: song.artist, converImgURL: song.imageURL))
                            },imageURL: song.imageURL, name: song.name)
                        }
                    }
                }
            } else {
                ProgressView()
            }
        }
        .task {
            await vm.doSearch(keyword: keyword, in: allSongs)
        }
    }
}

struct PlayListDetailSearchNotFound: View {
    var keyword:String
    var body: some View {
        ScrollViewOrNot {
            VStack {
                Text("未搜索到结果")
                Divider()
                if !keyword.isEmpty {
                    Text("没有歌名包含“\(keyword)”的音乐在歌单中")
                } else {
                    Text("请输入不为空的搜索关键词")
                }
            }
        }
    }
}



@Observable
class PlayListDetailSearchModel {
    var searchedRes:[PlayListModel.PlayListSong] = []
    var searching = false
    let backendMod = PlayListDetailSearchBackendModel()
    func doSearch(keyword:String,in songs:[PlayListModel.PlayListSong]) async {
        searching = true
        let searchResultTemp = await backendMod.doSearch(keyword: keyword, in: songs)
        if !Task.isCancelled {
            searchedRes = searchResultTemp
            searching = false
        }
    }
}

actor PlayListDetailSearchBackendModel {
    func doSearch(keyword:String,in songs:[PlayListModel.PlayListSong]) -> [PlayListModel.PlayListSong] {
        var searchResult:[PlayListModel.PlayListSong] = []
        for i in songs {
            if i.name.contains(keyword) {
                searchResult.append(i)
            }
        }
        return searchResult
    }
}

struct ForceReloadAlertContent: View {
    var body: some View {
        VStack {
            Text("正在刷新")
            Text("歌单较大，需要一会儿")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}


struct NoMusicInPlayList: View {
    var body: some View {
        VStack {
            Spacer()
            Image(systemName: "bookmark.slash.fill")
                .imageScale(.large)
            Spacer()
            Text("歌单内没有歌曲")
                .font(.headline)
            Text("请在手机上添加音乐")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
}



@Observable
class PlayListDetailPageModel:Hashable {
    static func == (lhs: PlayListDetailPageModel, rhs: PlayListDetailPageModel) -> Bool {
        lhs.id == rhs.id
    }
    
    
    var id = UUID()
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    var data:PlayListModel.PlayListDeatil
    var haveMore:Bool
    init(data: PlayListModel.PlayListDeatil,haveMore:Bool) {
        self.data = data
        self.haveMore = haveMore
    }
}
