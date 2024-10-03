//
//  MusicPlayingPage.swift
//  TuneWave Watch App
//
//  Created by Yukun Li on 2024/7/16.
//

import SwiftUI
import SwiftData
import WatchKit

struct NowPlayView: View {
    enum Page {
        case playingListPage
        case nowPlayPage
        case lyricsPage
    }
    var dismissMe:()->()
    var openOfflineCleaner:()->()
    @Environment(MusicPlayerHolder.self)
    var playerHolder:MusicPlayerHolder
    @State
    private var selectedTab = Page.nowPlayPage
    @State
    private var showMorePage = false
    @State
    var errorCheckTimer = Timer.publish(every: 1, tolerance: 1, on: .main, in: .default).autoconnect()
    @State
    var showErrorAlert = false
    @State
    var isAutoScrolling = true
    @State
    var showAutoScrollTip = false
    @State
    private var showInformation = false
    
    
    @AppStorage("PreferencedSeekMode")
    private var preferencedSeekModeRawValue:SeekPreference.RawValue = SeekPreference.song.rawValue//默认显示上一首下一首按钮
    var body: some View {
        
        ZStack {
            VStack {
                
                
                VStack(content: {
                    TabView(selection: $selectedTab, content: {
                        MusciPlayingListPagePack()
                            .tag(Page.playingListPage)
                        NowPlayingView()
                            .tag(Page.nowPlayPage)
                        LyricsViewPack(isAutoScrolling: $isAutoScrolling)
                            .tag(Page.lyricsPage)
                    })
                })
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        switch selectedTab {
                        case .playingListPage:
                            EmptyView()
                        case .nowPlayPage:
                            Button {
                                showMorePage = true
                            } label: {
                                Label("更多操作", systemImage: "ellipsis")
                            }
                        case .lyricsPage:
                            Button {
                                withAnimation(.easeOut) {
                                    isAutoScrolling.toggle()
                                }
                            } label: {
                                Label(isAutoScrolling ? "点此关闭歌词自动滚动" : "点此打开歌词自动滚动", systemImage: "digitalcrown.arrow.counterclockwise.fill")
                                    .transition(.blurReplace)
                            }
                        }
                    }
                }
                .navigationDestination(isPresented: $showMorePage, destination: {
                    NowPlayMoreActionPage(dismissMe: {
                        showMorePage = false
                        dismissMe()
                    },showPlayingListPage:{
                        slideToPage(.playingListPage)
                    }, showLyricPage: {
                        slideToPage(.lyricsPage)
                    }, openOfflineCleaner: myOpenOfflineCleaner)
                })
                
                .onReceive(errorCheckTimer, perform: { _ in
                    playerHolder.updateError()
                })
                
                .modifier(ShowAutoScrollTip(isAutoScrolling: isAutoScrolling, showTip: showTip))
                
            }
            .opacity(showInformation ? 0 : 1)
            .allowsHitTesting(showInformation ? false : true)
            
            AutoScrollTipView(isAutoScrolling:$isAutoScrolling,showAutoScrollTip: $showAutoScrollTip)
            
            VStack {
                if showInformation {
                    //优先显示错误信息
                    if !playerHolder.playingError.isEmpty {
                        ScrollViewOrNot {
                            ErrorView(errorText: playerHolder.playingError)
                        }
                    } else if !playerHolder.waitingPlayingReason.isEmpty {
                        ScrollViewOrNot {
                            VStack {
                                Text("即将开始播放")
                                    .font(.headline)
                                Divider()
                                Text(playerHolder.waitingPlayingReason)
                                    .foregroundStyle(.secondary)
                            }
                            .transition(.blurReplace)
                        }
                    }
                    
                }
            }
        }
        .onChange(of: selectedTab, initial: true, { oldValue, newValue in
            if newValue == Page.nowPlayPage {
                //在第三方app中播放过别的内容（比如说HomePod也在播放播客），再切回这里，NowPlay会停留在第三方app的内容，需要主动刷新一下。
                playerHolder.updateNowPlay(preferencedSeekModeRawValue: preferencedSeekModeRawValue)
            }
        })
        .animation(.smooth, value: showInformation)
        .onChange(of: playerHolder.playingError, initial: true) { oldValue, newValue in
            updateShowInformation()
        }
        .onChange(of: playerHolder.waitingPlayingReason, initial: true) { oldValue, newValue in
            updateShowInformation()
        }
    }
    func updateShowInformation() {
        if playerHolder.playingError.isEmpty && playerHolder.waitingPlayingReason.isEmpty {
            self.showInformation = false
        } else {
            self.showInformation = true
        }
    }
    func slideToPage(_ page:Page) {
        showMorePage = false
        Task {
            //等待页面关闭的动画完成，不然Tab切换没效果
            try? await Task.sleep(for: .seconds(0.3))//0.3s
            withAnimation(.smooth) {
                selectedTab = page
            }
        }
    }
    func myOpenOfflineCleaner() {
        showMorePage = false
        Task {
            //等待页面关闭的动画完成，不然watchOS 10下导航会不工作
            try? await Task.sleep(for: .seconds(0.3))//0.3s
            openOfflineCleaner()
        }
    }
}

struct NowPlayMoreActionPage: View {
    var dismissMe:()->()
    @State
    private var showNeedMoreMusicAlert = false
    @Environment(MusicPlayerHolder.self)
    private var playerHolder:MusicPlayerHolder
    @State
    private var enlargeButton = false
    @State
    private var showVolumePage = false
    var showPlayingListPage:()->()
    var showLyricPage:()->()
    var openOfflineCleaner:()->()
    var body: some View {
        ScrollViewOrNot {
            VStack {
                @Bindable var playerHolderBinding = playerHolder
                TuneWavePicker(selected: $playerHolderBinding.playingMode, showNeedMoreMusicAlert: $showNeedMoreMusicAlert,playerHolder:playerHolder)
                Button(action: {
                    showPlayingListPage()
                }, label: {
                    Label("播放列表", systemImage: "music.note.list")
                        .symbolEffect(.pulse, options: .repeating)
                })
                .scaleEffect(x: enlargeButton ? 2 : 1, y: enlargeButton ? 2 : 1, anchor: .bottom)
                Button(action: {
                    showLyricPage()
                }, label: {
                    Label("查看歌词", systemImage: "note.text")
                        .symbolEffect(.pulse, options: .repeating)
                })
                Button(action: {
                    showVolumePage = true
                }, label: {
                    Label("调节音量", systemImage: "volume.3.fill")
                        .symbolEffect(.pulse, options: .repeating)
                })
                NowPlayDownloadButton(openOfflineCleaner:openOfflineCleaner)
            }
            .alert("当前播放列表中只有一首歌，只能单曲循环，请先查看您的播放列表", isPresented: $showNeedMoreMusicAlert, actions: {
                Button("我去看看", action: {
                    focusToPlayListButton()
                })
            })
            .navigationDestination(isPresented: $showVolumePage, destination: {
                VolumePage()
            })
            
        }
    }
    func focusToPlayListButton() {
        withAnimation(.smooth.delay(0.5)) {
            enlargeButton = true
        } completion: {
            Task {
                try? await Task.sleep(for: .seconds(0.2))//0.2s
                withAnimation(.smooth) {
                    enlargeButton = false
                }
            }
        }
    }
}

struct VolumePage: View {
    var body: some View {
        ScrollViewOrNot {
            VStack {
                Text("请点击下方的小喇叭图标")
                VolumeIndicatorView()
                Text("然后旋转手表的侧边旋钮")
            }
            .scenePadding(.horizontal)
        }
    }
}

#Preview {
    VolumePage()
}

struct VolumeIndicatorView: WKInterfaceObjectRepresentable {
    
    typealias WKInterfaceObjectType = WKInterfaceVolumeControl
    
    func makeWKInterfaceObject(context: WKInterfaceObjectRepresentableContext<VolumeIndicatorView>) -> WKInterfaceVolumeControl {
        let control = WKInterfaceVolumeControl(origin: .local)
        control.setTintColor(.blue)
        return control
    }
    
    func updateWKInterfaceObject(_ control: WKInterfaceVolumeControl, context: WKInterfaceObjectRepresentableContext<VolumeIndicatorView>) {
        
    }
}

struct NowPlayDownloadButtonInner: View {
    @State
    var currentMusic:YiMusic
    @Environment(\.modelContext)
    private var modelContext
    @State
    private var impactHaptic = UUID()
    @State
    private var downloaded = false
    @State
    private var vm = DownloadButtonViewModel()
    var body: some View {
        Button(action:{
            impactHaptic = UUID()
            if !downloaded {
                vm.downloadMusicButton(yiMusic: currentMusic, modelContext: modelContext)
            } else {
                vm.showDeleteConfirmAlert = true
            }
        }) {
            if !downloaded {
                Label("下载音乐", systemImage: "icloud.and.arrow.down")
                    .symbolEffect(.pulse, options: .repeating)
                    .transition(.blurReplace.animation(.smooth.delay(0.2)))//延迟，避免交互式掉帧
            } else {
                VStack(alignment: .leading) {
                    Label("已下载", systemImage: "icloud.and.arrow.down")
                        .symbolEffect(.pulse, options: .repeating)
                    Text("可离线播放")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .transition(.blurReplace.animation(.smooth.delay(0.2)))//延迟，避免交互式掉帧
            }
        }
        .sensoryFeedback(.impact, trigger: impactHaptic)
        .alert("确认删除已下载的音乐吗？", isPresented: $vm.showDeleteConfirmAlert, actions: {
            Button(role: .destructive) {
                vm.deleteMusicButton(yiMusic: currentMusic, modelContext: modelContext)
            } label: {
                Text("删除")
            }
            Button(role: .cancel) { } label: {
                Text("取消")
            }
        })
        .sheet(item: $vm.downloadError) { pack in
            ScrollViewOrNot {
                ErrorView(errorText: pack.error.localizedDescription)
            }
        }
        .sheet(item: $vm.deleteError) { pack in
            ScrollViewOrNot {
                ErrorView(errorText: pack.error.localizedDescription)
            }
        }
        .onChange(of: currentMusic.isOnline, initial: true) { oldValue, newValue in
            self.downloaded = updateDownloadedStatus(isOnline: newValue)
            print("更新downloaded到\(downloaded)")
        }
    }
    func updateDownloadedStatus(isOnline:Bool) -> Bool {
        if isOnline {
            return false
        } else {
            return true
        }
    }
}

struct NowPlayDownloadButton: View {
    var openOfflineCleaner:()->()
    @Environment(MusicPlayerHolder.self)
    private var playerHolder:MusicPlayerHolder
    @State
    private var currentMusic:YiMusic? = nil
    var body: some View {
        VStack {
            if let currentMusic {
                NowPlayDownloadButtonInner(currentMusic: currentMusic)
                    .transition(.blurReplace)
            } else {
                //没有正在播放的音乐，不显示下载按钮
            }
        }
        .onChange(of: playerHolder.currentMusic, initial: true, { oldValue,newValue in
            withAnimation(.smooth) {
                currentMusic = newValue
            }
        })
    }
}

@MainActor
@Observable
class DownloadButtonViewModel {
    var showDeleteConfirmAlert = false
    var downloadError:ErrorPack? = nil
    var deleteError:ErrorPack? = nil
    func downloadMusicButton(yiMusic:YiMusic?,modelContext:ModelContext) {
        do {
            downloadError = nil
            try downloadMusic(yiMusic: yiMusic,modelContext:modelContext)
        } catch {
            downloadError = .init(error: error)
        }
    }
    private
    func downloadMusic(yiMusic:YiMusic?,modelContext:ModelContext) throws {
        guard let yiMusic else {
            throw DownloadOrDeleteMusicError.notPlaying
        }
        //这样就说明用户已经显式下载了，而不是自动缓存
        yiMusic.isOnline = false
        print("已经标记为下载状态")
        try modelContext.save()
    }
    func deleteMusicButton(yiMusic:YiMusic?,modelContext:ModelContext) {
        do {
            deleteError = nil
            try deletedMusic(yiMusic: yiMusic,modelContext:modelContext)
        } catch {
            deleteError = .init(error: error)
        }
    }
    private
    func deletedMusic(yiMusic:YiMusic?,modelContext:ModelContext) throws {
        guard let yiMusic else {
            throw DownloadOrDeleteMusicError.notPlaying
        }
        //变回自动缓存的音乐
        yiMusic.isOnline = true
        print("已经标记为自动缓存状态")
        try modelContext.save()
    }
    enum DownloadOrDeleteMusicError:Error,LocalizedError {
        case notPlaying
        var errorDescription: String? {
            switch self {
            case .notPlaying:
                "当前没有正在播放的音乐"
            }
        }
    }
}

struct OptionalOnChangeView: View {
    var body: some View {
        Rectangle()
            .fill(.clear)
            .frame(width: 1, height: 1, alignment: .center)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}


//原生的Picker会出现背景毛玻璃丢失、返回按钮消失的问题。
struct TuneWavePicker: View {
    @Binding
    var selected:PlayingMode
    @Binding
    var showNeedMoreMusicAlert:Bool
    @State
    var playerHolder:MusicPlayerHolder
    @State
    private var showSheet = false
    var body: some View {
        Button {
            showSheet = true
        } label: {
            VStack(alignment: .leading, content: {
                Text("当前播放模式")
                Text(selected.humanReadbleName())
                    .contentTransition(.numericText())
                    .foregroundStyle(.secondary)
                    .font(.footnote)
            })
        }
        .navigationDestination(isPresented: $showSheet, destination: {
            List {
                Button(action: {
                    itemPicked(PlayingMode.singleLoop, name: "单曲循环", needMoreThanOneSong: false)
                }, label: {
                    HStack(content: {
                        Text("单曲循环")
                        Spacer()
                        if selected == PlayingMode.singleLoop {
                            Image(systemName: "checkmark")
                        }
                    })
                })
                
                Button(action: {
                    itemPicked(PlayingMode.playingListLoop, name:"顺序播放", needMoreThanOneSong: true)
                }, label: {
                    HStack(content: {
                        Text("顺序播放")
                        Spacer()
                        if selected == PlayingMode.playingListLoop {
                            Image(systemName: "checkmark")
                        }
                    })
                })
                Button(action: {
                    itemPicked(PlayingMode.random, name: "随机", needMoreThanOneSong: true)
                }, label: {
                    
                    HStack(content: {
                        Text("随机")
                        Spacer()
                        if selected == PlayingMode.random {
                            Image(systemName: "checkmark")
                        }
                    })
                })
            }
            .listStyle(.carousel)
            .navigationTitle("播放模式")
        })
    }
    func itemPicked(_ item:PlayingMode,name:String,needMoreThanOneSong:Bool) {
        showSheet = false
        if needMoreThanOneSong && (playerHolder.playingList.count <= 1) {
            showNeedMoreMusicAlert = true
            //拒绝切换，跳到单曲循环
            withAnimation(.smooth) {
                selected = .singleLoop
            }
        } else {
            withAnimation(.smooth) {
                self.selected = item
            }
        }
    }
}


// MARK: 切换自动滚动开关的时候显示一个小横幅
struct ShowAutoScrollTip: ViewModifier {
    var isAutoScrolling:Bool
    var showTip:()->()
    func body(content: Content) -> some View {
        content
            .onChange(of: isAutoScrolling, initial: false) { oldValue, newValue in
                if oldValue != newValue {
                    showTip()
                }
            }
    }
}


extension NowPlayView {
    func showTip() {
        Task { @MainActor in
            withAnimation(.snappy) {
                showAutoScrollTip = true
            }
            try? await Task.sleep(for: .seconds(1))//1s
            withAnimation(.snappy) {
                showAutoScrollTip = false
            }
        }
    }
}
struct AutoScrollTipView: View {
    @Binding
    var isAutoScrolling:Bool
    @Binding
    var showAutoScrollTip:Bool
    var body: some View {
        if showAutoScrollTip {
            VStack {
                Spacer()
                Text("自动滚动已\(isAutoScrolling ? "打开" : "关闭")")
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.accentColor.opacity(0.8)).fill(Material.ultraThin))
            }
            .transition(.move(edge: .bottom))
        }
    }
}
//⬆️MARK: 切换自动滚动开关的时候显示一个小横幅



struct Zero3Delay<V:View>: View {
    var content:()->(V)
    @State
    private var showMe = false
    var body: some View {
        if showMe {
            content()
        } else {
            Rectangle()
                .frame(width: 1, height: 1, alignment: .center)
                .hidden()
                .onLoad {
                    Task {
                        if showMe == false {
                            try? await Task.sleep(for: .seconds(0.3))
                            withAnimation(.smooth) {
                                showMe = true
                            }
                        }
                    }
                }
        }
    }
}





