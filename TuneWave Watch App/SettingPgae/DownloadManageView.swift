//
//  CleanerView.swift
//  TuneWave
//
//  Created by Yukun Li on 2024/9/13.
//

import SwiftUI
import SwiftData

@MainActor
@Observable
class DownloadManageViewModel {
    var fetchAllMusicCacheTask:Task<Void,Never>?
    var loading = true
    var errorPack:ErrorPack? = nil
    var downloadedMusics:[YiMusicDetailedShell] = []
    var selection:Set<YiMusicDetailedShell> = .init()
    func fetchAllDownloadedMusic(modelContext:ModelContext) {
        fetchAllMusicCacheTask?.cancel()
        fetchAllMusicCacheTask = Task {
            loading = true
            do {
                errorPack = nil
                let newDownloadedMusics = try await getAllDownloadedMusic(modelContext: modelContext)
                guard !Task.isCancelled else { return }
                downloadedMusics = newDownloadedMusics
            } catch {
                guard !Task.isCancelled else { return }
                errorPack = .init(error: error)
            }
            loading = false
        }
    }
    
    private
    func getAllDownloadedMusic(modelContext:ModelContext) async throws -> [YiMusicDetailedShell] {
        try await PersistentModel.fetchFromDBVersionC(predicate: #Predicate<YiMusic> { music in
            !music.isOnline//现在要找的是已下载的音乐
        }, sortBy: { $0.name.localizedCompare($1.name) == .orderedAscending
            /*按照首字母排序*/
        }, modelContext: modelContext)
    }
}


struct DownloadManageView: View {
    @State
    private var vm = DownloadManageViewModel()
    @Environment(\.modelContext)
    private var modelContext
    @State
    private var showConfirmAlert = false
    @State
    private var deleteSelectError:ErrorPack? = nil
    var body: some View {
        VStack {
            if vm.downloadedMusics.isEmpty {
                if vm.loading {
                    ProgressView()
                        .transition(.blurReplace.animation(.smooth))
                } else if let errorPack = vm.errorPack {
                    ErrorView(errorText: errorPack.error.localizedDescription)
                        .transition(.blurReplace.animation(.smooth))
                } else {
                    ContentUnavailableView("没有下载的音乐", systemImage: "music.note")
                        .transition(.blurReplace.animation(.smooth))
                }
            } else {
                List {
                    Section("下载了以下音乐（\(vm.downloadedMusics.count)首）", content: {
                        ForEach(vm.downloadedMusics) { music in
                            DownloadManageViewRow(myMusic: music, selection: $vm.selection)
                        }
                    })
                }
                .animation(.smooth, value: vm.downloadedMusics)
                .transition(.blurReplace.animation(.smooth))
            }
        }
        .onLoad {
            vm.fetchAllDownloadedMusic(modelContext: modelContext)
        }
        .toolbar {
            if !vm.selection.isEmpty {
                ToolbarItemGroup(placement: .bottomBar) {
                    DownloadManageViewDeleteSelectionButton(showConfirmAlert: $showConfirmAlert)
                }
            }
            if !vm.downloadedMusics.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    DownloadManageViewSelectAndDeselectButton(selection: $vm.selection, downloadedMusics: vm.downloadedMusics)
                }
            }
        }
        .navigationTitle("管理已下载的音乐")
        .alert("确认删除这\(vm.selection.count)首已下载的音乐吗？", isPresented: $showConfirmAlert, actions: {
            Button(role: .destructive) {
                withAnimation(.smooth) {
                    showConfirmAlert = false
                } completion: {
                    deleteDownloadedMusics()
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
    func deleteDownloadedMusics() {
        do {
            deleteSelectError = nil
            let selectIDs:[UUID] = vm.selection.map { music in
                music.id
            }
            try modelContext.delete(model: YiMusic.self, where: #Predicate<YiMusic>{ music in
                selectIDs.contains(music.id)
            })
            vm.downloadedMusics.removeAll { music in
                vm.selection.contains(music)
            }
            vm.selection.removeAll()
        } catch {
            deleteSelectError = .init(error: error)
        }
    }
}

struct DownloadManageViewSelectAndDeselectButton: View {
    @Binding
    var selection:Set<YiMusicDetailedShell>
    
    var downloadedMusics:[YiMusicDetailedShell]
    var body: some View {
        
        Button(role: .destructive) {
            if (downloadedMusics.count == selection.count) && (Set(downloadedMusics) == selection) {
                for music in downloadedMusics {
                    selection.remove(music)
                }
            } else {
                for music in downloadedMusics {
                    selection.insert(music)
                }
            }
        } label: {
            Image(systemName: "checklist.checked")
                .accessibilityLabel(Text("选中全部已下载的音乐"))
        }
    }
}

struct DownloadManageViewDeleteSelectionButton: View {
    @Binding
    var showConfirmAlert:Bool
    var body: some View {
        Spacer()
        Button(role: .destructive) {
            showConfirmAlert = true
        } label: {
            Image(systemName: "trash.slash.fill")
                .foregroundStyle(.red)
                .accessibilityLabel(Text("删除所选的已下载的音乐"))
        }
    }
}

struct DownloadManageViewRow: View {
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

