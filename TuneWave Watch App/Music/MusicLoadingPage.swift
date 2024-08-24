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
    static func == (lhs: MusicPlayShip, rhs: MusicPlayShip) -> Bool {
        lhs.id == rhs.id
    }
    
    var id = UUID()
    var musicID:String
    var name:String
    var artist:String
    
    var coverImgURL:URL
    //本音乐属于的播放列表
    //会用这个播放列表作为音乐播放时负一屏的播放列表
    var playList:[PlayListModel.PlayListSong]
}

struct PlayFromCacheView: View {
    @State
    var vm:MusicLoadingViewModel
    var cachedMusic:YiMusic
    var playList:[PlayListModel.PlayListSong]
    @Environment(MusicPlayerHolder.self)
    private var playerHolder:MusicPlayerHolder
    @Environment(\.modelContext)
    private var modelContext
    var body: some View {
        
            if let error = vm.playError {
                ScrollViewOrNot {
                    ErrorView(errorText: error.localizedDescription)
                }
            } else {
                VStack(spacing:0) {
                    Spacer()//把backButton顶到最顶上去
                    ProgressView()
                        .controlSize(.extraLarge)//"从缓存的音乐开始播放"
                    HStack {
                        
                        Label("音乐正在加载", systemImage: "arrow.triangle.2.circlepath.icloud")
                            .font(.headline)
                            .lineLimit(1)
                            .minimumScaleFactor(0.1)
                            .scaledToFit()
                    }
                    .transition(.blurReplace)
                    .scenePadding(.horizontal)
                    .onLoad {
                        Task {
                            await vm.playMusicWithCached(yiMusic: cachedMusic, playList: playList, playerHolder: playerHolder, modelContext: modelContext)
                        }
                    }
                    Spacer()
                }
            }
    }
}


//音乐很小，不需要流播。在搜索列表中点击一首歌曲先缓存完成再播放，避免封面图片异步加载、歌词异步加载、后台网络连接缓存歌曲等困难。

//像健身圆环一样，3D的网易云标志浮出来转个圈的动画。允许用户手势交互。表冠往下滚动可以看到加载进度条。取消按钮总是在左上角，避免误触。
@MainActor
struct PlayMusicPage: View {
    var musicID:String
    var name:String
    var artist:String
    var converImgURL:URL
    var playList:[PlayListModel.PlayListSong]
    @Binding
    var cachedMusic:YiMusic?
    var showPlayPage:()->()
    var cancelAction:()->()
    
    @State
    private
    var downloadMod:MusicLoader?
    @State
    private
    var vm:MusicLoadingViewModel = .init()
    @Environment(YiUserContainer.self)
    private
    var user:YiUserContainer
    @Environment(MusicPlayerHolder.self)
    private
    var playerHolder:MusicPlayerHolder
    @Environment(\.modelContext)
    private
    var modelContext
    @State
    private
    var scrollPosition:String? = nil
    
    var body: some View {
        VStack {
            if let downloadMod {
                if let cachedMusic {
                    PlayFromCacheView(vm: vm, cachedMusic: cachedMusic, playList: playList)
                } else {
                    OnlineLoadingView(vm:vm,downloadMod:downloadMod, scrollPosition: $scrollPosition)
                }
            } else {
                //黑屏就行，这个过程应该只会持续一个RunLoop
            }
        }
        .onLoad {
            Task {
                await pageOpenTask()
            }
        }
        .animation(.smooth, value: vm.step1Done)
        .animation(.smooth, value: vm.step1Error)
        .animation(.smooth, value: vm.step2Done)
        .animation(.smooth, value: vm.step2Error)
        .animation(.smooth, value: vm.step3Done)
        .animation(.smooth, value: vm.step3Error)
        .animation(.smooth, value: vm.step4Done)
        .animation(.smooth, value: vm.step4Error)
        .onChange(of: vm.step1Done, initial: true, { oldValue, newValue in actionWhenLoadingDone() })
        .onChange(of: vm.step2Done, initial: true, { oldValue, newValue in actionWhenLoadingDone() })
        .onChange(of: vm.step3Done, initial: true, { oldValue, newValue in actionWhenLoadingDone() })
        .onChange(of: vm.step4Done, initial: true, { oldValue, newValue in actionWhenLoadingDone() })
        .onChange(of: vm.step1Error, initial: true, { oldValue, newValue in vm.updateHaveAnyStepError() })
        .onChange(of: vm.step2Error, initial: true, { oldValue, newValue in vm.updateHaveAnyStepError() })
        .onChange(of: vm.step3Error, initial: true, { oldValue, newValue in vm.updateHaveAnyStepError() })
        .onChange(of: vm.step4Error, initial: true, { oldValue, newValue in vm.updateHaveAnyStepError() })
        .animation(.smooth, value: vm.haveAnyStepError)
        .overlay(alignment: .topLeading) {
            LightCancelButton(symbolName: "chevron.backward", accessbilityLabel: "返回", action: {
                vm.isCanceledPlay = true
                cancelAction()
            })
        }
        .ignoresSafeArea(edges: .top)
        .toolbar(.hidden, for: .navigationBar)
    }
    
    func actionWhenLoadingDone() {
        if vm.step1Done && vm.step2Done && vm.step3Done && vm.step4Done {
            if vm.playError == nil {
                do {
                    vm.playError = nil
                    guard let downloadMod else {
                        throw MusicLoadingViewModel.PlayError.noDownloadMode
                    }
                    //vm.playMusic包含一些在MainActor上的步骤，会导致小卡顿，因此在动画完成后再执行，把小卡顿藏起来
                                  withAnimation(.smooth) {
                                      vm.doneLoading = true
                                  } completion: {
                                      Task {
                                          await vm.playMusic(downloadMod: downloadMod, modelContext: modelContext, playerHolder: playerHolder, playList: playList)
                                      }
                                  }
                } catch {
                    vm.playError = error
                }
            }
        }
    }
    func pageOpenTask() async {
        do {
            vm.showPlayPage = self.showPlayPage
            self.downloadMod = MusicLoader(isOnline: true, musicID: musicID, name: name, artist: artist, coverImgURL: converImgURL, vm: vm, user: user)
            guard let downloadMod else {
                throw NeverError.neverError
            }
            if let cached = try await downloadMod.getCachedMusic(modelContext: modelContext) {
                self.cachedMusic = cached
            }  else {
                await requestMusicTask(downloadMod:downloadMod)
            }
        } catch {
            vm.playError = error
        }
    }
}

struct OnlineLoadingView: View {
    @State
    var vm:MusicLoadingViewModel
    @State
    var downloadMod:MusicLoader?
    @Binding
    var scrollPosition:String?
    var body: some View {
        ScrollView {
            VStack {
                AnimatedLoadingView()
                VStack {
                    VStack {
                        if vm.haveAnyStepError {//有任意一个步骤出错了
                            Label("音乐加载失败", systemImage: "exclamationmark.icloud")
                                .font(.headline)
                                .transition(.blurReplace)
                        } else {
                            Label("音乐正在加载", systemImage: "arrow.triangle.2.circlepath.icloud")
                                .font(.headline)
                                .transition(.blurReplace)
                        }
                    }
                    Divider()
                    ZStack {
                        //这个组件用来保证最小高度
                        FourLineHeightPlaceholder()
                            .padding(.vertical)
                        //如果显示内容不足最小高度，以最小高度显示；如果显示内容超过最小高度，以内容高度显示
                        VStack(content: {
                            if let downloadMod {
                                
                                VStack(alignment: .leading,spacing:16.7) {
                                    if !vm.step1Done {
                                        PlayMusicStepView(loadongText: "正在获取音乐完整信息",symbolName: "list.bullet.clipboard.fill", errorTitle: "获取音乐完整信息失败",error:vm.step1Error)
                                    }
                                    if !vm.step2Done {
                                        PlayMusicStepView(loadongText: "正在获取音乐封面图",symbolName: "photo.badge.arrow.down.fill", errorTitle:"获取音乐封面图失败",error:vm.step2Error)
                                    }
                                    if !vm.step3Done {
                                        PlayMusicStepView(loadongText: "正在获取歌词",symbolName: "text.word.spacing", errorTitle:"获取歌词失败",error:vm.step3Error)
                                    }
                                    if vm.step1Done {
                                        //步骤1没出错才会去做步骤4
                                        if !vm.step4Done {
                                            PlayMusicStepView(loadongText: "正在缓存音频",symbolName: "arrow.triangle.2.circlepath.icloud.fill", errorTitle:"缓存音频失败",error:vm.step4Error)
                                            if vm.step4Error == nil {
                                                if let totalSize = vm.audioDataSize {
                                                    PlayMusicPageProgressView(totalSize:totalSize,doneProgress:vm.audioDownloadProgress)
                                                } else {
                                                    NeverErrorView(remoteControlTag: "PlayMusicPage")
                                                }
                                            }
                                        }
                                    }
                                    
                                    if vm.doneLoading {
                                        ProgressView()//"步骤已完成，关闭页面，开始播放"
                                            .transition(.blurReplace)
                                    } else  if let error = vm.playError {
                                        ScrollViewOrNot {
                                            ErrorView(errorText: error.localizedDescription)
                                        }
                                    } else {
                                        //还在下载中，会由上面的部分来显示状态
                                    }
                                }
                                
                                
                            } else {
                                Text("初始化加载类")
                                    .transition(.blurReplace)
                            }
                        })
                        .id("Status")
                        .scenePadding(.horizontal)
                    }
                }
                .scenePadding(.horizontal)
            }
            .scrollTargetLayout()
        }
        .scrollPosition(id: $scrollPosition, anchor: .bottom)
        //SceneKit在SwiftUI中不支持透明背景，因此设为黑色
        .background(Color.black)
    }
}

struct PlayMusicPageProgressView: View {
    var totalSize:Double
    var doneProgress:Double
    var body: some View {
        VStack(content: {
            ProgressView(value: doneProgress, total: 1)
            let doneMB:String = String(format: "%.2f", (doneProgress * totalSize) / 1024576)
            let totalMB:String = String(format: "%.2f", (totalSize) / 1024576)
            Text("\(doneMB)/\(totalMB)MB")
        })
        .transition(.blurReplace)
        .animation(.smooth, value: doneProgress)
    }
}


extension PlayMusicPage {
    //不然用户一直傻傻的等待在3DLogo，需要主动往下滚动
    func scrollToError() {
        withAnimation(.smooth) {
            scrollPosition = "Status"
        }
    }
    func requestMusicTask(downloadMod:MusicLoader) async {
        vm.step1Error = nil
        vm.step2Error = nil
        vm.step3Error = nil
        vm.step4Error = nil
        let _: [Void] = await withTaskGroup(of: Void.self) { group in
            //步骤1需要在步骤4前
            group.addTask { @MainActor in
                do {
                    try await downloadMod.step1()
                    vm.step1Done = true
                    //步骤1没出错才能做步骤4
                    do {
                        try await downloadMod.step4()
                        vm.step4Done = true
                    } catch {
                        vm.step4Error = error.localizedDescription
                        scrollToError()
                    }
                } catch {
                    vm.step1Error = error.localizedDescription
                    scrollToError()
                }
                return ()
            }
            //其余步骤并行化
            group.addTask { @MainActor in
                do {
                    try await downloadMod.step2()
                    vm.step2Done = true
                } catch {
                    vm.step2Error = error.localizedDescription
                    scrollToError()
                }
            }
            //其余步骤并行化
            group.addTask { @MainActor in
                do {
                    try await downloadMod.step3()
                    vm.step3Done = true
                } catch {
                    vm.step3Error = error.localizedDescription
                    scrollToError()
                }
            }
            return []
        }
    }
}


struct PlayMusicStepView: View {
    var loadongText:String
    var symbolName:String
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
            Label(loadongText, systemImage: symbolName)
                .symbolRenderingMode(.multicolor)
                .transition(.blurReplace)
        }
    }
}


