//
//  ContentView.swift
//  TuneWave Watch App
//
//  Created by Yukun Li on 2024/6/12.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @State
    private var userContainer:YiUserContainer?
    @Environment(\.modelContext)
    private var modelContext
    @State
    private var recoveryLoginError:String? = nil
    @Query(FetchDescriptor<YiUser>())
    private var users:[YiUser]
    @State
    private var showNowPlayView = false
    @State
    private var playerHolder = MusicPlayerHolder()
    @State
    private var actionExcuter = GoPlayListAndPickAMsuicAction()
    @State
    private var showMyPlayListPage = false
    @State
    private var openSettingPage:Bool = false
    @State
    private var openOfflineCleaner:UUID = UUID()
    var body: some View {
        VStack {
            NavigationStack {
                ScrollView {
                    VStack {
                        if let recoveryLoginError {
                            ErrorViewWithListInlineStyle(title: "恢复登录状态时出错了", errorText: recoveryLoginError)
                        }
                        if let nowPlay = playerHolder.currentMusic {
                            Button {
                                showNowPlayView = true
                            } label: {
                                VStack(alignment: .leading) {
                                    Text("正在播放")
                                    Text(nowPlay.name)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        
                        
                        NavigationLink(destination: {
                            LoginPage()
                                .environment(userContainer)
                        }) {
                            if userContainer != nil {
                                Label("账号信息", systemImage: "person.badge.shield.checkmark.fill")
                            } else {
                                Label("登录网易云账号", systemImage: "person.fill.badge.plus")
                            }
                        }
                        
                        if let userContainer { //用户先把账号登好，不然这么多入口摆在这儿容易误导用户
                            Button {
                                showMyPlayListPage = true
                            } label: {
                                Label("歌单", systemImage: "star.fill")
                            }
                            
                            
                            Button {
                                openSettingPage = true
                            } label: {
                                Label("设置", systemImage: "gear.circle.fill")
                            }
                            
                            
                            NavigationLink {
                                AboutPage()
                            } label: {
                                Label("关于", systemImage: "apple.terminal.on.rectangle.fill")
                            }
                            
                            DisclaimerView()
                        }
                    }
                }
                .navigationDestination(isPresented: $showMyPlayListPage, destination: {
                    MyPlayList()
                        .environment(actionExcuter)
                        .environment(userContainer)
                })
                .modifier(SettingPageNavigationLink(openSettingPage: $openSettingPage, openOfflineCleaner: $openOfflineCleaner))
                .modifier(MusicPlayerCover(showNowPlayView: $showNowPlayView, openOfflineCleaner: myOpenOfflineCleaner))
                .modifier(DataBaseAccess())
                .modifier(ManagerPlayingList())
                .modifier(SavePlayingModeChange())
                .modifier(GoPlayListAndPickAMsuicActionModifier(showNowPlayView: $showNowPlayView, showMyPlayListPage: $showMyPlayListPage))
                .environment(actionExcuter)
                .environment(userContainer)
                
                .onChange(of: users, initial: true, { oldValue, newValue in
                    do {
                        //默认选择最近一次登录的用户
                        if let selectedUser = try CurrentUserFinder().currentActivedUserIfHave(modelContext: modelContext) {
                            self.userContainer = .init(activedUser: selectedUser)
                        } else {
                            //没登录过或者已经退出登录了
                            self.userContainer = nil
                        }
                    } catch {
                        self.recoveryLoginError = error.localizedDescription
                    }
                })
                .modifier(RefreshCookie(userContainer: $userContainer))
                .modifier(ShowDisclaimer())
                .navigationTitle("悦音音乐")
            }
            .environment(playerHolder)
        }
    }
    func myOpenOfflineCleaner() {
        Task {
            showMyPlayListPage = false
            //导航堆栈的推入，好像不等也没事，在watchOS 10下是如此
            openSettingPage = true
            try? await Task.sleep(for: .seconds(0.6))//0.5s就不能正常工作了
            openOfflineCleaner = UUID()
        }
    }
}

struct GoPlayListAndPickAMsuicActionModifier: ViewModifier {
    @Environment(GoPlayListAndPickAMsuicAction.self)
    private var actionExcuter:GoPlayListAndPickAMsuicAction
    @Binding
    var showNowPlayView:Bool
    @Binding
    var showMyPlayListPage:Bool
    func body(content: Content) -> some View {
        content
            .onAppear {
                actionExcuter.closePlayerCover = {
                    showNowPlayView = false
                }
                actionExcuter.openMyPlayListPage = {
                    showMyPlayListPage = true
                }
            }
    }
}

struct ShowDisclaimer: ViewModifier {
    @State
    private var showAlert = false
    @State
    private var alertText = ""
    @AppStorage("DisclaimerAccepted")
    var disclaimerAccepted = false
    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: $showAlert, content: {
                //虽然根本不需要Navigation，但为了navigationBarBackButtonHidden能工作，所以放一个NavigationStack
                ScrollView {
                    VStack(content: {
                        VStack(alignment: .center, content: {
                            Text(alertText)
                                .font(.headline)
                                .multilineTextAlignment(.center)
                        })
                        .scenePadding(.horizontal)
                        Button("同意") {
                            showAlert = false
                            disclaimerAccepted = true
                        }
                        Button("拒绝",role:.destructive) {
                            exit(0)
                        }
                    })
                }
                
                .toolbar {
                    //不允许关闭
                    ToolbarItem(placement: .cancellationAction) {
                        Text("")
                    }
                }
            })
            .onLoad {
                if disclaimerAccepted == false {
                    if let url = Bundle.main.url(forResource: "DisclaimerContent", withExtension: "md") {
                        if let text = try? String(contentsOf: url) {
                            print("免责声明\(alertText)")
                            showAlert = true
                            
                            Task {
                                try? await Task.sleep(for: .seconds(0.1))
                                withAnimation(.snappy) {
                                    alertText = text
                                }
                            }
                        }
                    }
                }
                
            }
    }
}




struct RefreshCookie: ViewModifier {
    @Environment(\.modelContext)
    var modelContext
    @Binding
    var userContainer:YiUserContainer?
    @State
    var refreshedCookie = false
    func body(content: Content) -> some View {
        content
            .onChange(of: userContainer,initial: true, { oldValue, newValue in
                guard let user = self.userContainer?.activedUser else {
                    //都没登录，刷新什么登录状态？
                    return
                }
                //避免因为刷新Cookie触发users变化又触发刷新Cookie
                if !refreshedCookie {
                    refreshedCookie = true
                    Task {
                        do {
                            let refresher = LoginRefresher()
                            try await refresher.refreshLogin(for: user, modelContext: modelContext)
                        } catch {
                            print("刷新登录状态失败\(error.localizedDescription)")
                        }
                    }
                }
            })
    }
}

@MainActor
struct MusicPlayerCover: ViewModifier {
    @Environment(MusicPlayerHolder.self)
    var playerHolder
    @State
    var ship:MusicPlayShip? = nil
    @Binding
    var showNowPlayView:Bool
    var openOfflineCleaner:()->()
    @State
    private var sceneVM = SceneModelShip()
    @Environment(GoPlayListAndPickAMsuicAction.self)
    private var actionExcuter:GoPlayListAndPickAMsuicAction
    @State
    private var cachedMusic:YiMusic? = nil
    @Environment(\.modelContext)
    private var modelContext
    @AppStorage("ignore Silent Mode")
    private var ignoreSlientMode = true
    func body(content: Content) -> some View {
        content
            .sheet(item: $ship) { ship in
                PlayMusicPage(musicID: ship.musicID, name: ship.name, artist: ship.artist, converImgURL: ship.coverImgURL, playList: ship.playList, cachedMusic: $cachedMusic,showPlayPage:{
                    self.ship = nil
                    self.showNowPlayView = true
                },cancelAction: {
                    self.ship = nil
                })
                .environment(sceneVM)
            }
            .onReceive(playMusic, perform: { musicInfo in
                playMusicAction(musicInfo: musicInfo)
            })
            .sheet(isPresented: $showNowPlayView, content: {
                NavigationStack {
                    NowPlayView(dismissMe:{
                        showNowPlayView = false
                    }, openOfflineCleaner: myOpenOfflineCleaner)
                }
            })
            .onLoad {
                Task(priority: .background) {
                    do {
                        try await sceneVM.sceneModel.load()
                    } catch {
                        print("3D场景加载失败\(error.localizedDescription)")
                    }
                }
            }
            .onLoad {
                if ignoreSlientMode {
                    //APP启动，先激活正确的音频会话
                    playerHolder.setupAVAudioSession()
                }
            }
    }
    func myOpenOfflineCleaner() {
        showNowPlayView = false
        Task {
            //等待页面关闭的动画完成，不然watchOS 10下导航会不工作
            try? await Task.sleep(for: .seconds(0.3))
            openOfflineCleaner()
        }
    }
    func playMusicAction(musicInfo:MusicPlayShip) {
        //play cover sheet弹出过程中这个动画是能看到的
        withAnimation(.smooth) {
            actionExcuter.showPleasePickBanner = false
        }
        if let cachedMusic:YiMusic = try? MusicLoader.getCachedMusic(musicID:musicInfo.musicID,modelContext: modelContext) {
            self.cachedMusic = cachedMusic
        } else {
            //这里需要重置，清理掉上次的cached，不然下次播放还是上次的歌了
            self.cachedMusic = nil
        }
        self.ship = musicInfo
    }
}

struct DataBaseAccess: ViewModifier {
    @Environment(MusicPlayerHolder.self)
    private var playerHolder
    @Environment(\.modelContext)
    private var modelContext
    func body(content: Content) -> some View {
        content
            .onLoad {
                //我这个View一直持有modelContext（考虑到这首我们aapp的核心功能，一直持有也不算太过分），这样playerHolder想访问数据库的时候就可以通过我直接访问。
                //我的责任只有musicShellToRealObject，其它时候要访问，尽量中函数里由发起者把modelContext传进去。
                playerHolder.musicShellToRealObject = { shell in
                    let targetMusicID = shell.musicID
                    guard let matched = try modelContext.fetch(FetchDescriptor(predicate: #Predicate<YiMusic>{ music in
                        music.musicID == targetMusicID
                    })).first else {
                        throw MusicPlayerHolder.MusicShellToRealObjectError.musicLost
                    }
                    return matched
                }
            }
    }
}
