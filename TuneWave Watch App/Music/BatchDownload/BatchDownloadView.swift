//
//  BatchDownload.swift
//  TuneWave
//
//  Created by Yukun Li on 2024/9/25.
//

import SwiftUI
import SwiftData

///批量下载本身就应该连Wi-Fi下载，不然会很慢。既然要连Wi-Fi，那就不需要isOnline模式了，直接按照下载的品质。
struct BatchDownloadPack: View {
    let playList:[PlayListModel.PlayListSong]
    @Binding
    var showMe:Bool
    @State
    private var showRealView = true
    var body: some View {
        VStack {
            if showRealView {
                BatchDownload(playList: playList,showMe:$showMe)
                    .transition(.blurReplace.animation(.smooth))
            } else {
                ProgressView()
                    .onAppear {
                        showRealView = true
                    }
                    .transition(.blurReplace.animation(.smooth))
            }
        }
    }
}

fileprivate
struct BatchDownload: View {
    let playList:[PlayListModel.PlayListSong]
    @Binding
    var showMe:Bool
    @Environment(YiUserContainer.self)
    private
    var user:YiUserContainer
    @Environment(\.modelContext)
    private var modelContext
    @State
    private var vm = BatchDownloadViewModel()
    var body: some View {
        VStack(content: {
            if vm.batchTask.isEmpty {
                ContentUnavailableView("歌单内无音乐", systemImage: "square.stack.3d.up.slash.fill")
            } else {
                ScrollViewReader { proxy in
                    List {
                        Section("歌单中共有\(vm.batchTask.count)首音乐") {
                            ForEach(vm.batchTask) { downloadTask in
                                BatchDownloadRow(downloadTask: downloadTask)
                                    .id(downloadTask)
                            }
                        }
                    }
                    .toolbar {
                        ToolbarItemGroup(placement: .bottomBar) {
                            Spacer()
                            Button(action:{
                                vm.pushActionsPage = true
                            }) {
                                Image(systemName: "ellipsis")
                                    .accessibilityRepresentation {
                                        Label("更多操作", systemImage: "ellipsis")
                                    }
                            }
                        }
                    }
                    .onAppear {
                        vm.scrollProxy = proxy
                    }
                }
            }
        })
        .sheet(isPresented: $vm.pushActionsPage, content: {
            BatchDownloadActionView(vm: vm)
        })
        .navigationTitle("批量下载")
        .onLoad {
            vm.batchTask = playList.map({ music in
                    .init(music: music)
            })
            vm.startBatchDownload(user: user, modelContext: modelContext)
        }
        .onChange(of: showMe, initial: false) { oldValue, newValue in
            //离开页面了，取消批量下载
            if newValue == false {
                vm.batchDownloadTask?.cancel()
            }
        }
    }
}

struct BatchDownloadActionView: View {
    @State
    var vm:BatchDownloadViewModel
    @State
    private var showAlert = false
    var body: some View {
        NavigationStack {
            ScrollViewOrNot {
                VStack {
                    Button {
                        showAlert = false
                        switch vm.scrollToDownloadingItem() {
                        case .done:
                            //此时本页面已经在scrollToDownloadingItem里被pop了
                            break
                        case .noDownloadingItem:
                            showAlert = true
                        }
                    } label: {
                        Label("滚动到正在下载的位置", systemImage: "arcade.stick.and.arrow.down")
                    }
                    Text("已下载\(vm.doneDownloadCount)首歌")
                        .contentTransition(.numericText())
                        .animation(.smooth, value: vm.doneDownloadCount)
                        .padding(.vertical)
                        .scenePadding(.horizontal)
                }
                .alert("没有正在下载的音乐\n可能是已经全部下载完了，或者全部下载失败了，或者歌单内没有音乐", isPresented: $showAlert, actions: { })
            }
        }
    }
}


@MainActor
@Observable
class BatchDownloadViewModel {
    
    var batchTask:[DownloadTask] = []
    var batchDownloadTask:Task<Void,Never>?
    var doneDownloadCount = 0
    var pushActionsPage = false
    var scrollProxy:ScrollViewProxy? = nil
    
    func startBatchDownload(user:YiUserContainer,modelContext:ModelContext) {
        batchDownloadTask?.cancel()
        batchDownloadTask = Task {
            for downloadTask in batchTask {
                //如果已经离开批量下载页面了，就不要下载了，不然在后台占网速/占性能/占空间就不好了
                guard !Task.isCancelled else {
                    print("已取消批量下载")
                    return }
                do {
                    downloadTask.status = .downloading
                    let music = downloadTask.music
                    let (yiMusic,type) = try await readFromCacheOrDownload(music: music, isOnline: false, user: user, modelContext: modelContext)
                    guard !Task.isCancelled else {
                        print("批量下载已取消")
                        return
                    }
                    switch type {
                    case .cached:
                        //已经有下载的（已经存在数据库里了），不需要重复写入
                        break
                    case .download:
                        //如果有同一首歌的isOnline版，先删掉
                        let targetMusicID:String = yiMusic.musicID
                        try modelContext.delete(model: YiMusic.self,where: #Predicate<YiMusic>{ inDBMusic in
                            inDBMusic.musicID == targetMusicID
                        })
                        //存入数据库
                        modelContext.insert(yiMusic)
                        try modelContext.save()
                    }
                    downloadTask.status = .done
                } catch {
                    downloadTask.status = .failed(error.localizedDescription)
                }
                updateDoneCount()
            }
        }
    }
    
    func scrollToDownloadingItem() -> scrollToDownloadingItemResult {
        if let targetItem = batchTask.filter { task in
            task.status == .downloading
        }.randomElement() {
            Task {
                pushActionsPage = false
                try? await Task.sleep(for: .seconds(0.4))
            }
            withAnimation(.smooth) {
                
                scrollProxy?.scrollTo(targetItem, anchor: .center)
            }
            return .done
        } else {
            return .noDownloadingItem
        }
    }
    
    enum scrollToDownloadingItemResult {
        case done
        case noDownloadingItem
    }
   
    private
    func updateDoneCount() {
        let count:Int = self.batchTask.filter({ task in
            task.status == .done
            }).count
        self.doneDownloadCount = count
    }
    enum ResultType {
        case cached
        case download
    }
    private
    func readFromCacheOrDownload(music:PlayListModel.PlayListSong,isOnline:Bool,user:YiUserContainer,modelContext:ModelContext) async throws -> (YiMusic,ResultType) {
        //isOnline: false设为下载模式
        let downloadMod = MusicLoader(isOnline: false, musicID: music.songID, name: music.name, artist: music.artist, coverImgURL: music.imageURL, user: user)
        if let cached = try await downloadMod.getCachedMusic(modelContext: modelContext),!cached.isOnline/*已经有下载的版本了，不需要重复下载*/ {
            return (cached,.cached)
        }  else {
            return (try await downloadOne(downloadMod: downloadMod,isOnline:isOnline),.download)
        }
    }
    private
    func downloadOne(downloadMod:MusicLoader,isOnline:Bool) async throws -> YiMusic {
        //提前把文件的权限设置好
        let fileURL = URL.createTemporaryURL(extension: ".download")//Step4中最后是self.audioData = try Data(contentsOf: filePath)，所以扩展名其实不影响
        try setAllowAccessOnLock(for: fileURL)
        let _: [Void] = try await withThrowingTaskGroup(of: Void.self) { group in
            //步骤1需要在步骤4前
            group.addTask {
                try await downloadMod.step1()
                try await downloadMod.step4(fileURL: fileURL, onProgressChange: { progress in })
            }
            //其余步骤并行化
            group.addTask { @MainActor in
                try await downloadMod.step2()
            }
            //其余步骤并行化
            group.addTask { @MainActor in
                try await downloadMod.step3()
            }
            //开始运行任务
            for try await _ in group { }
            return []
        }
        return try await downloadMod.generateFinalMusicObject(isOnline:isOnline)
    }
}


@MainActor
@Observable
class DownloadTask:Identifiable,Equatable,Hashable {
    static func == (lhs: DownloadTask, rhs: DownloadTask) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    var id:String {
        music.id
    }
    let music:PlayListModel.PlayListSong
    var status:DownloadStatus
    init(music: PlayListModel.PlayListSong) {
        self.music = music
        self.status = .waiting
    }
}
enum DownloadStatus:Equatable,Hashable {
    case waiting
    case downloading
    case done
    case failed(String)//简化架构，不支持重新开始失败的音乐，要重试请再进入一次下载页面，或者单曲点击播放然后再下载。
}
