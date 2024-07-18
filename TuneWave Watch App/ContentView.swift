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
    var userContainer:YiUserContainer?
    @Environment(\.modelContext)
    var modelContext
    @State
    var recoveryLoginError:String? = nil
    @Query(FetchDescriptor<YiUser>())
    var users:[YiUser]
    @State
    var showNowPlayView = false
    @State
    var playerHolder = MusicPlayerHolder()
    var body: some View {
        VStack {
            NavigationStack {
                ScrollView {
                    VStack {
                        if let recoveryLoginError {
                            ErrorViewWithListInlineStyle(title: "恢复登录状态时出错了", errorText: recoveryLoginError)
                        }
                        if let nowPlay = playerHolder.yiMusic {
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
                        if let userContainer {
                            NavigationLink {
                                MyPlayList()
                                .environment(userContainer)
                            } label: {
                                Label("歌单", systemImage: "star.fill")
                            }
                        }
                        NavigationLink {
                            AboutPage()
                        } label: {
                            Label("关于", systemImage: "apple.terminal.on.rectangle.fill")
                        }
                        DisclaimerView()
                    }
                }
                .modifier(MusicPlayerCover(showNowPlayView: $showNowPlayView)).environment(playerHolder)
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
                            try? await Task.sleep(nanoseconds:100000000)//0.1s
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
                            print("刷新登录状态失败，这可能是用户没联网，但是不用提示，用户总会有一次联网的")
                        }
                    }
                }
            })
    }
}

struct MusicPlayerCover: ViewModifier {
    @Environment(MusicPlayerHolder.self)
    var playerHolder
    @State
    var ship:MusicPlayShip? = nil
    @Binding
    var showNowPlayView:Bool
    func body(content: Content) -> some View {
        content
            .sheet(item: $ship) { ship in
                PlayMusicPage(musicID: ship.musicID, name: ship.name, artist: ship.artist, converImgURL: ship.converImgURL,showPlayPage:{
                    self.ship = nil
                    self.showNowPlayView = true
                })
                    .environment(playerHolder)
            }
            .onReceive(playMusic, perform: {
                self.ship = $0
            })
            .sheet(isPresented: $showNowPlayView, content: {
                NavigationStack {
                    NowPlayView()
                }
                    .environment(playerHolder)
            })
    }
}


#Preview {
    ContentView()
}
