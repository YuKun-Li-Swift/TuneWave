//
//  PlayListDetailPgae.swift
//  TuneWave Watch App
//
//  Created by Yukun Li on 2024/7/11.
//

import SwiftUI
import SwiftData

struct PlayListDetailPage: View {
    var playList:UserPlayListModel.PlayListObj
    @State
    var vm:PlayListDetailPageModel?
    @State
    var reqMod = PlayListModel()
    @Environment(\.modelContext)
    private var modelContext
    var body: some View {
        LoadingSkelton {
            PlayListDetailLoadingView()
        } successView: {
            VStack {
                if let vm {
                    PlayListDetailList(vm: vm)
                    .id(vm)
                } else {
                    NeverErrorView(remoteControlTag: "playListDetailPageNeverError")
                }
            }
        } errorView: { error in
            APIErrorDisplay(remoteControlTag: "playListDetailPage", error: error)
        } loadingAction: {
            let cachedPlayList =  try await reqMod.getPlaylistDetail(playlist: playList,useCache: true)
            let localMusic = try await OnlineToLocalConverter.convert(onlineSongs: cachedPlayList.0.songs, modelContext: modelContext)
            let newVM = PlayListDetailPageModel(data:cachedPlayList.0, haveMore: cachedPlayList.1, haveMoreCount: cachedPlayList.2)
            self.vm = newVM
            vm?.loadingByNoCache(playList: playList, reqMod: reqMod, modelContext: modelContext)
        }
        .navigationTitle(playList.name)
    }
}

struct PlayListDetailLoadingView: View {
    @State
    private var showLine2 = false
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

@MainActor
struct PlayListDetailList: View {
    @State
    var vm:PlayListDetailPageModel
    @State
    private var showNoCacheLoadingError = false
    @State
    private var cacheRowVM = CachedMusicOnlyRowModel()
    @Environment(\.modelContext)
    private var modelContext
    @Environment(GoPlayListAndPickAMsuicAction.self)
    private var actionExcuter:GoPlayListAndPickAMsuicAction
    @State
    private var scrollProxy:ScrollViewProxy?
    var body: some View {
        VStack {
            if vm.data.songs.isEmpty {
                NoMusicInPlayList()
            } else {
                ScrollViewReader { proxy in
                    List {
                        if actionExcuter.showPleasePickBanner {
                            PleasePickBannerPlayListDetail()
                        }
                        if vm.haveMore {
                            PlayListDetailListHaveMoreBanner(count:vm.data.songs.count,notAvailableCount: vm.haveMoreCount)
                        }
                        CachedMusicOnly(vm:cacheRowVM,songs:vm.data.songs)
                        ForEach(vm.data.songs) { song in
                            MusicRowSingleLine(tapAction:{
                                playMusic.send(.init(musicID: song.songID, name: song.name, artist: song.artist, coverImgURL: song.imageURL, playList: vm.data.songs))
                            },imageURL: song.imageURL, name: song.name)
                            //因为静默刷新，为了避免刷新的时候导致批量重载，我们需要显式添加id
                            .id(song.id)
                        }
                    }
                    .onAppear {
                        self.scrollProxy = proxy
                    }
                  
                }
            }
        }
        .navigationDestination(isPresented: $cacheRowVM.pushPage, destination: {
            PlayListCachedMusicPage(vm:cacheRowVM, songs: vm.data.songs)
        })
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                Rectangle()
                    .frame(width: 1, height: 1, alignment: .center)
                    .hidden()
                Rectangle()
                    .frame(width: 1, height: 1, alignment: .center)
                    .hidden()
                if vm.forceIgnoreCacheLoadProgressing {
                    ProgressView()
                } else if let _ = vm.forceIgnoreCacheLoadError {
                    Button {
                        showNoCacheLoadingError = true
                    } label: {
                        Label("歌单加载遇到问题", systemImage: "exclamationmark.icloud.fill")
                    }

                }
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    vm.showMoreActionPage = true
                } label: {
                    Label("更多操作", systemImage: "ellipsis")
                }
            }
        }
        .onAppear {
            cacheRowVM.checkNetworkConnect()
        }
        .sheet(isPresented: $vm.showMoreActionPage, content: {
            PlayListDetailActionsSheet(vm: vm)
        })
        .alert("未能从云端同步最新歌单\n"+(vm.forceIgnoreCacheLoadError ?? "未知错误"), isPresented: $showNoCacheLoadingError, actions: {
            
        })
        .onChange(of: actionExcuter.showPleasePickBanner, initial: true) { _, showPleasePickBanner in
            if showPleasePickBanner {
                scrollToPleasePickBanner()
            }
        }
    }
    func scrollToPleasePickBanner() {
        withAnimation(.smooth) {
            self.scrollProxy?.scrollTo("showPleasePickBanner", anchor: .top)
        }
    }
}

struct PleasePickBannerPlayListDetail: View {
    var body: some View {
        HStack(content: {
            Text("请在下方音乐中选择你想加入播放列表的")
                .multilineTextAlignment(.leading)
                .shadow(color: .black.opacity(0.8), radius: 6, x: 3, y: 3)
            .padding()
            Spacer()
        })
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(Color.accentColor.gradient))
            .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
            .id("showPleasePickBanner")
    }
}


struct PlayListDetailActionsSheet: View {
    @State
    var vm:PlayListDetailPageModel
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
                                try? await Task.sleep(nanoseconds:300000000)//0.3s，等自己所处的sheet先收回去
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
                    }
                }
            }
        }
    }
}



struct PlayListDetailListHaveMoreBanner: View {
    var count:Int
    var notAvailableCount:Int
    var body: some View {
        if count >= 1000 {//超过一千首歌只会显示前1000首
            VStack(alignment: .leading) {
                Text("歌单内还有更多歌曲，但受限于性能原因，暂不显示。")
                Label("建议您为Apple Watch单独创建一个小歌单。", systemImage: "lightbulb.fill")
            }
            .font(.footnote)
        } else {
            VStack(alignment: .leading) {
                Text("歌单内还有更多歌曲，但受限于版权原因，无法播放。")
                Text("（缺少\(notAvailableCount)首音乐）")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Label("建议您在iPhone上的网易云中检查一下这个歌单", systemImage: "lightbulb.fill")
                    .font(.footnote)
            }
            .font(.footnote)
        }
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
                                playMusic.send(.init(musicID: song.songID, name: song.name, artist: song.artist, coverImgURL: song.imageURL, playList: allSongs))
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
            VStack(spacing:12.3) {
                HomeMakeSlashSymbol(symbolName: "music.note", accessibilityLabel: "未搜索到音乐")
                    .imageScale(.large)
                Text("未搜索到结果")
                    .font(.headline)
                Divider()
                if !keyword.isEmpty {
                    Text("没有歌名包含“\(keyword)”的音乐在歌单中")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("本搜索严格区分大小写、简繁体")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Text("请输入不为空的搜索关键词")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 12.3)
            .scenePadding(.horizontal)
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
        ScrollViewOrNot {
            VStack {
                Text("正在刷新")
                Text("歌单较大，需要一会儿")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 12.3)
            .scenePadding(.horizontal)
        }
    }
}


struct NoMusicInPlayList: View {
    var body: some View {
        ScrollViewOrNot {
            VStack(spacing:12.3) {
                Image(systemName: "star.slash.fill")
                    .imageScale(.large)
                Text("歌单内没有音乐")
                    .font(.headline)
                Text("请在手机上的“网易云音乐”APP中添加音乐")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("如已添加，请点击右下角刷新")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 12.3)
            .scenePadding(.horizontal)
        }
    }
}



@Observable
class PlayListDetailPageModel:Hashable {
    static func == (lhs: PlayListDetailPageModel, rhs: PlayListDetailPageModel) -> Bool {
        lhs.id == rhs.id
    }
    var showSearchPage = false
    var showMoreActionPage = false
    var id = UUID()
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    var data:PlayListModel.PlayListDeatil
    var haveMore:Bool
    var haveMoreCount:Int
    init(data: PlayListModel.PlayListDeatil,haveMore:Bool,haveMoreCount:Int) {
        self.data = data
        self.haveMore = haveMore
        self.haveMoreCount = haveMoreCount
    }
    
    
    var forceIgnoreCacheLoadProgressing = true
    var forceIgnoreCacheLoadError:String? = nil
    func update(data: PlayListModel.PlayListDeatil,haveMore:Bool,haveMoreCount:Int) {
        self.data = data
        self.haveMore = haveMore
        self.haveMoreCount = haveMoreCount
    }
  
    //从缓存请求做完后，再不用缓存做一遍，避免用户看到的是过时的歌单列表
    func loadingByNoCache(playList:UserPlayListModel.PlayListObj,reqMod:PlayListModel,modelContext:ModelContext) {
        Task {
            forceIgnoreCacheLoadError = nil
            forceIgnoreCacheLoadProgressing = true
            
            do {
                let forceedPlayListParsed = try await reqMod.getPlaylistDetail(playlist: playList, useCache: false)
                update(data:  forceedPlayListParsed.0, haveMore: forceedPlayListParsed.1,haveMoreCount:forceedPlayListParsed.2)
            } catch {
                forceIgnoreCacheLoadError = error.localizedDescription
            }
            forceIgnoreCacheLoadProgressing = false
        }
    }
    
}
