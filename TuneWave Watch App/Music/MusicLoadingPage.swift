//
//  MusicLoadingPage.swift
//  TuneWave Watch App
//
//  Created by Yukun Li on 2024/6/20.
//

import SwiftUI
import Combine

let playMusic = PassthroughSubject<MusicPlayShip,Never>()


struct MusicPlayShip:Identifiable,Equatable {
    var id = UUID()
    var musicID:String
    var name:String
    var artist:String
    var converImgURL:URL
}

//音乐很小，不需要流播。在搜索列表中点击一首歌曲先缓存完成再播放，避免封面图片异步加载、歌词异步加载、后台网络连接缓存歌曲等困难。

//像健身圆环一样，3D的网易云标志浮出来转个圈的动画。允许用户手势交互。表冠往下滚动可以看到加载进度条。取消按钮总是在左上角，避免误触。
@MainActor
struct PlayMusicPage: View {
    var musicID:String
    var name:String
    var artist:String
    var converImgURL:URL
    @State
    var downloadMod:MusicLoader?
    @State
    var vm:MusicLoadingViewModel = .init()
    @Environment(YiUserContainer.self)
    var user:YiUserContainer
    @Environment(MusicPlayerHolder.self)
    var playerHolder:MusicPlayerHolder
    @Environment(\.modelContext)
    var modelContext
    @State
    var cachedMusic:YiMusic? = nil
    var body: some View {
        NavigationStack {
            if !vm.showPlayPage {
                VStack {
                    
                        Label("音乐正在加载", systemImage: "arrow.triangle.2.circlepath.icloud")
                            .font(.headline)
                        Divider()
                        VStack(content: {
                            if let downloadMod {
                                if let cachedMusic {
                                    if let error = vm.playError {
                                        ScrollViewOrNot {
                                            ErrorView(errorText: error.localizedDescription)
                                        }
                                    } else {
                                        Text("从缓存的音乐开始播放")
                                            .transition(.blurReplace)
                                            .task {
                                                vm.playMusicWithCached(yiMusic: cachedMusic, playerHolder: playerHolder)
                                            }
                                    }
                                } else if !vm.step1Done {
                                    PlayMusicStepView(loadongText: "正在获取音乐完整信息", errorTitle: "获取音乐完整信息失败",error:vm.step1Error)
                                        
                                } else if !vm.step2Done {
                                    PlayMusicStepView(loadongText: "正在获取音乐封面图", errorTitle:"获取音乐封面图失败",error:vm.step2Error)
                                } else if !vm.step3Done {
                                    PlayMusicStepView(loadongText: "正在获取歌词", errorTitle:"获取歌词失败",error:vm.step3Error)
                                } else if !vm.step4Done {
                                    PlayMusicStepView(loadongText: "正在缓存音频", errorTitle:"缓存音频失败",error:vm.step4Error)
                                    if vm.step4Error == nil {
                                        if let totalSize = vm.audioDataSize {
                                            VStack(content: {
                                                ProgressView(value: vm.audioDownloadProgress, total: 1)
                                                let doneMB:String = String(format: "%.2f", (vm.audioDownloadProgress * totalSize) / 1024576)
                                                let totalMB:String = String(format: "%.2f", (totalSize) / 1024576)
                                                Text("\(doneMB)/\(totalMB)MB")
                                            })
                                            .transition(.blurReplace)
                                            .animation(.smooth, value: vm.audioDownloadProgress)
                                        } else {
                                            NeverErrorView(remoteControlTag: "PlayMusicPage")
                                        }
                                    }
                                } else {
                                    if let error = vm.playError {
                                        ScrollViewOrNot {
                                            ErrorView(errorText: error.localizedDescription)
                                        }
                                    } else {
                                        Text("步骤已完成，关闭页面，开始播放")
                                            .transition(.blurReplace)
                                            .task {
                                                await vm.playMusic(downloadMod: downloadMod, modelContext: modelContext, playerHolder: playerHolder)
                                            }
                                    }
                                }
                            } else {
                                Text("初始化加载器")
                                    .transition(.blurReplace)
                            }
                        })
                        .animation(.smooth, value: vm.step1Done)
                        .animation(.smooth, value: vm.step1Error)
                        .animation(.smooth, value: vm.step2Done)
                        .animation(.smooth, value: vm.step2Error)
                        .animation(.smooth, value: vm.step3Done)
                        .animation(.smooth, value: vm.step3Error)
                        .animation(.smooth, value: vm.step4Done)
                        .animation(.smooth, value: vm.step4Error)
                        .task { @MainActor in
                            do {
                                self.downloadMod = MusicLoader(musicID: musicID, name: name, artist: artist, coverImgURL: converImgURL, vm: vm, user: user)
                                guard let downloadMod else {
                                    throw NeverError.neverError
                                }
                                if let cached = try await downloadMod.getCachedMusic(modelContext: modelContext) {
                                    self.cachedMusic = cached
                                }  else {
                                    vm.step1Error = nil
                                    do {
                                        try await downloadMod.step1()
                                        vm.step1Done = true
                                    } catch {
                                        vm.step1Error = error.localizedDescription
                                    }
                                    vm.step2Error = nil
                                    do {
                                        try await downloadMod.step2()
                                        vm.step2Done = true
                                    } catch {
                                        vm.step2Error = error.localizedDescription
                                    }
                                    vm.step3Error = nil
                                    do {
                                        try await downloadMod.step3()
                                        vm.step3Done = true
                                    } catch {
                                        vm.step3Error = error.localizedDescription
                                    }
                                    vm.step4Error = nil
                                    do {
                                        try await downloadMod.step4()
                                        vm.step4Done = true
                                    } catch {
                                        vm.step4Error = error.localizedDescription
                                    }
                                }
                            } catch {
                                vm.playError = error
                            }
                        }
                    
                }
            } else {
                NowPlayView()
            }
        }
    }

}


struct PlayMusicStepView: View {
    var loadongText:String
    var errorTitle:String
    var error:String?
    var body: some View {
        if let e = error {
            VStack {
                Text(errorTitle)
                Text(e)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .transition(.blurReplace)
        } else {
            Text(loadongText)
                .transition(.blurReplace)
        }
    }
}


