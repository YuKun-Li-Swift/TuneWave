//
//  CleanerView.swift
//  TuneWave
//
//  Created by Yukun Li on 2024/9/13.
//

import SwiftUI
import SwiftData


struct CleanerView: View {
    @Binding
    var openOfflineCleaner:UUID
    @State
    private var showOfflineCleanView = false
    @State
    private var showDownloadManageView = false
    var body: some View {
        //未来实现
        //删除isOnline的YiMusic
        //删除SDWebImage的图片缓存
        //删除Alamofire的Session缓存
        ScrollView(content: {
            VStack {
                Button {
                    showOfflineCleanView = true
                } label: {
                    Label("清理音乐缓存", systemImage: "music.quarternote.3")
                }
                Button {
                    showDownloadManageView = true
                } label: {
                    Label("管理已下载的音乐", systemImage: "music.note.list")
                }
            }
        })
        .navigationTitle("清理空间")
        .navigationDestination(isPresented: $showOfflineCleanView) {
            OfflineCacheCleaner()
        }
        .navigationDestination(isPresented: $showDownloadManageView) {
            DownloadManageView()
        }
    }
}

struct ErrorPack:Identifiable {
    var id = UUID()
    var error:Error
}

@MainActor
@Observable
class OfflineCacheCleanerViewModel {
    var fetchAllMusicCacheTask:Task<Void,Never>?
    var loading = true
    var errorPack:ErrorPack? = nil
    var cachedMusics:[YiMusicDetailedShell] = []
    var selection:Set<YiMusicDetailedShell> = .init()
    func fetchAllMusicCache(modelContext:ModelContext) {
        fetchAllMusicCacheTask?.cancel()
        fetchAllMusicCacheTask = Task {
            loading = true
            do {
                errorPack = nil
                let newCachedMusics = try await getAllCachedMusic(modelContext: modelContext)
                guard !Task.isCancelled else { return }
                cachedMusics = newCachedMusics
            } catch {
                guard !Task.isCancelled else { return }
                errorPack = .init(error: error)
            }
            loading = false
        }
    }
    
    
    private
    func getAllCachedMusic(modelContext:ModelContext) async throws -> [YiMusicDetailedShell] {
        try await PersistentModel.fetchFromDBVersionC(predicate: #Predicate<YiMusic> { music in
            music.isOnline//取在线音乐（在线的代表是缓存的，而不是用户下载的）
        }, sortBy: { $0.name.localizedCompare($1.name) == .orderedAscending
            /*按照首字母排序*/
        }, modelContext: modelContext)
    }
     
    func toMusicDetail(musics:FetchResultsCollection<YiMusic>,cachedMusic: inout [YiMusicDetailedShell]) async throws -> [YiMusicDetailedShell] {
        for music in musics.shuffled() {
            try await func2(music: music)
//            try await (music.toDetailedShell())
        }
        return []
    }
    func func2(music:YiMusic) async throws {
        try await print(music.toDetailedShell())
    }
}


struct OfflineCacheCleaner: View {
    @State
    private var vm = OfflineCacheCleanerViewModel()
    @Environment(\.modelContext)
    private var modelContext
    @State
    private var showConfirmAlert = false
    @State
    private var deleteSelectError:ErrorPack? = nil
    var body: some View {
        VStack {
            if vm.cachedMusics.isEmpty {
                if vm.loading {
                    ProgressView()
                        .transition(.blurReplace.animation(.smooth))
                } else if let errorPack = vm.errorPack {
                    ErrorView(errorText: errorPack.error.localizedDescription)
                        .transition(.blurReplace.animation(.smooth))
                } else {
                    ContentUnavailableView("没有缓存的音乐", systemImage: "music.note")
                        .transition(.blurReplace.animation(.smooth))
                }
            } else {
                List {
                    Section("缓存了以下音乐（\(vm.cachedMusics.count)首）", content: {
                        ForEach(vm.cachedMusics) { music in
                            OfflineCacheCleanerRow(myMusic: music, selection: $vm.selection)
                        }
                    })
                }
                .animation(.smooth, value: vm.cachedMusics)
                .transition(.blurReplace.animation(.smooth))
            }
        }
        .onLoad {
            vm.fetchAllMusicCache(modelContext: modelContext)
        }
        .toolbar {
            if !vm.selection.isEmpty {
                ToolbarItemGroup(placement: .bottomBar) {
                    DeleteSelectionButton(showConfirmAlert: $showConfirmAlert)
                }
            }
            if !vm.cachedMusics.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    SelectAndDeselectButton(selection: $vm.selection, cachedMusics: vm.cachedMusics)
                }
            }
        }
        .navigationTitle("清理音乐缓存")
        .alert("确认删除这\(vm.selection.count)首音乐的缓存吗？", isPresented: $showConfirmAlert, actions: {
            Button(role: .destructive) {
                withAnimation(.smooth) {
                    showConfirmAlert = false
                } completion: {
                    deleteOnlineMusic()
                }
            } label: {
                Text("删除")
            }
            Button(role: .cancel,action: { }, label: {
                Text("返回")
            })
        })
        .sheet(item: $deleteSelectError) { pack in
            ScrollViewOrNot {
                ErrorView(errorText: pack.error.localizedDescription)
            }
        }
    }
    func deleteOnlineMusic() {
        do {
            deleteSelectError = nil
            let selectIDs:[UUID] = vm.selection.map { music in
                music.id
            }
            try modelContext.delete(model: YiMusic.self, where: #Predicate<YiMusic>{ music in
                selectIDs.contains(music.id)
            })
            vm.cachedMusics.removeAll { music in
                vm.selection.contains(music)
            }
            vm.selection.removeAll()
        } catch {
            deleteSelectError = .init(error: error)
        }
    }
}

struct SelectAndDeselectButton: View {
    @Binding
    var selection:Set<YiMusicDetailedShell>
    
    var cachedMusics:[YiMusicDetailedShell]
    var body: some View {
        
        Button(role: .destructive) {
            if (cachedMusics.count == selection.count) && (Set(cachedMusics) == selection) {
                for music in cachedMusics {
                    selection.remove(music)
                }
            } else {
                for music in cachedMusics {
                    selection.insert(music)
                }
            }
        } label: {
            Image(systemName: "checklist.checked")
                .accessibilityLabel(Text("选中全部缓存的音乐"))
        }
    }
}

struct DeleteSelectionButton: View {
    @Binding
    var showConfirmAlert:Bool
    var body: some View {
        Spacer()
        Button(role: .destructive) {
            showConfirmAlert = true
        } label: {
            Image(systemName: "trash.slash.fill")
                .foregroundStyle(.red)
                .accessibilityLabel(Text("删除所选的缓存音乐"))
        }
    }
}

struct OfflineCacheCleanerRow: View {
    @State
    var myMusic:YiMusicDetailedShell
    @Binding
    var selection:Set<YiMusicDetailedShell>
    @State
    private var meInSelection = false
    var body: some View {
        MusicRowSingleLine(tapAction: {
            if meInSelection {
                selection.remove(myMusic)
            } else {
                selection.insert(myMusic)
            }
        }, imageURL: .constant(myMusic.albumImgURL), name: myMusic.name,hightlight:$meInSelection)
        .onChange(of: selection, initial: true) { oldValue, newValue in
            withAnimation(.easeOut) {//列表快速下滑的时候，效果比.smooth好看点
                meInSelection = newValue.contains(myMusic)
            }
        }
    }
}

