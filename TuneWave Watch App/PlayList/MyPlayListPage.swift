//
//  MyPlayList.swift
//  TuneWave Watch App
//
//  Created by Yukun Li on 2024/7/9.
//

import SwiftUI
let screen = WKInterfaceDevice.current().screenBounds

@MainActor
struct MyPlayList: View {
    @Environment(YiUserContainer.self)
    private var userContainer:YiUserContainer?
    @Environment(GoPlayListAndPickAMsuicAction.self)
    private var actionExcuter:GoPlayListAndPickAMsuicAction
    @State
    private var mod = UserPlayListModel()
    @State
    private var vm :MyPlayListViewModel? = nil
    @State
    private var leftColumn:[UserPlayListModel.PlayListObj] = []
    @State
    private var rightColumn:[UserPlayListModel.PlayListObj] = []
    @State
    private var selected:UserPlayListModel.PlayListObj?
    @State
    private var whereIsModTimer = Timer.publish(every: 0.1, on: .main, in: .default).autoconnect()
    @State
    private var initLayout = true
    @State
    private var scrollProxy:ScrollViewProxy?
    @State
    private var isPresentedLoginOutPage = false
    var body: some View {
        VStack {
            if let userContainer {
                LoadingSkelton {
                    ProgressView()
                } successView: {
                    VStack {
                        if let vm {
                            if vm.playListContainer.playlists.isEmpty {
                                NeedReloginView(isPresentedLoginOutPage:$isPresentedLoginOutPage)
                            } else {
                                ScrollViewReader { proxy in
                                    ScrollView {
                                        if actionExcuter.showPleasePickBanner {
                                            PleasePickBannerMyPlayList()
                                        }
                                        VStack {
                                            HStack(alignment: .top, spacing: 16.7/3) {//左右两列应该.top对其，不然左边一列文本更长的情况下，会在首屏看不到右边那列的顶了
                                                VStack(alignment: .center, spacing: 16.7/3) {
                                                    ForEach(leftColumn) { i in
                                                        PlayListGrid(playList: i,selected:$selected)
                                                            .id(i.playListID)
                                                    }
                                                }
                                                VStack(alignment: .center, spacing: 16.7/3) {
                                                    if !rightColumn.isEmpty {
                                                        ForEach(rightColumn) { i in
                                                            PlayListGrid(playList: i,selected:$selected)
                                                                .id(i.playListID)
                                                        }
                                                    } else {
                                                        //如果新号只有一个歌单
                                                        //占位，不然布局不对了
                                                        Spacer()
                                                            .hidden()
                                                    }
                                                }
                                            }
                                            IgnoreCacheLoadingView(vm: vm)
                                        }
                                    }
                                    .onChange(of: vm.playListContainer, initial: true) { oldValue, newValue in
                                        //首次打开页面，不要动画；后续歌单增减了（比如AJAX请求到了新的歌单）需要有动画
                                        let animation:Animation? = {
                                            if initLayout {
                                                initLayout = false
                                                return nil
                                            } else {
                                                return .smooth
                                            }
                                        }()
                                        withAnimation(animation) {
                                            (leftColumn,rightColumn) = vm.rebuildPlayList(origin: newValue.playlists)
                                        }
                                    }
                                    .onAppear {
                                        self.scrollProxy = proxy
                                    }
                                }
                            }
                        } else {
                            NeverErrorView(remoteControlTag: "MyPlayList")
                        }
                    }
                    .navigationDestination(item: $selected) { playlist in
                        PlayListDetailPage(playList: playlist)
                            .environment(actionExcuter)
                    }
                } errorView: { error in
                    APIErrorDisplay(remoteControlTag: "myPlayListPage", error: error)
                } loadingAction: {
                    let user = userContainer.activedUser
                    let cachedPlayList = try await mod.getMyPlayList(user: user, useCache: true)
                    let newVM = MyPlayListViewModel(playList: cachedPlayList)
                    self.vm = newVM
                    //从缓存请求做完后，再不用缓存做一遍，避免用户看到的是过时的歌单列表
                    vm?.loadingByNoCache(mod: mod, user: user, cachedPlayList: cachedPlayList)
                }
                .onChange(of: actionExcuter.showPleasePickBanner, initial: true) { _, showPleasePickBanner in
                    if showPleasePickBanner {
                        scrollToPleasePickBanner()
                    }
                }
            } else {
                RequireLoginView()
            }
        }
        
        .navigationDestination(isPresented: $isPresentedLoginOutPage) {
            LoginOutPage()
        }
    }
    func scrollToPleasePickBanner() {
        withAnimation(.smooth) {
            self.scrollProxy?.scrollTo("showPleasePickBanner", anchor: .top)
        }
    }
}

struct NeedReloginView: View {
    @Binding
    var isPresentedLoginOutPage:Bool
    var body: some View {
        ScrollViewOrNot {
            VStack(spacing:12.3) {
                Text("网易云登录已失效，请重新登录")
                Button("重新登录") {
                    isPresentedLoginOutPage = true
                }
            }
            .padding(.vertical, 12.3)
            .scenePadding(.horizontal)
        }
    }
}

struct RequireLoginView: View {
    @Environment(\.dismiss)
    private var dismiss
    var body: some View {
        ScrollViewOrNot {
            VStack(spacing:12.3) {
                Text("请先登录网易云账号")
                Button("去登录") {
                    dismiss()
                }
            }
            .padding(.vertical, 12.3)
            .scenePadding(.horizontal)
        }
    }
}

#Preview {
    RequireLoginView()
}

struct PleasePickBannerMyPlayList: View {
    var body: some View {
        HStack(content: {
            Text("请在下方歌单中选择你上次听的")
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



struct IgnoreCacheLoadingView: View {
    @State
    var vm :MyPlayListViewModel
    var body: some View {
        if vm.forceIgnoreCacheLoadProgressing {
            ProgressView()
                .padding()
        } else if let errorText = vm.forceIgnoreCacheLoadError {
            VStack(alignment: .leading) {
                Divider()
                Text("歌单加载出错")
                Text(errorText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("上方显示的歌单内容可能不是最新的")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}



import SDWebImageSwiftUI

struct PlayListGrid: View {
    var playList:UserPlayListModel.PlayListObj
    @Binding
    var selected:UserPlayListModel.PlayListObj?
    var body: some View {
        Button {
            selected = playList
        } label: {
            VStack(alignment: .center, spacing: 16.7/2) {
                if let url = playList.coverImgUrl {
                    WebImage(url: url.lowRes(xy2x: Int(screen.width)), transaction: .init(animation: .smooth)) { phase in
                        switch phase {
                        case .empty:
                            FixSizeImageLarge(systemName: "photo.badge.arrow.down")
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .transition(.blurReplace.animation(.smooth))
                                .clipShape(RoundedRectangle(cornerRadius: 16.7/3, style: .continuous))
                        case .failure(let error):
                            FixSizeImageLarge(systemName: "wifi.exclamationmark")
                        }
                    }
                } else {
                    FixSizeImageLarge(systemName: "photo")
                }
                
                HStack {
                    Spacer()
                    Text(playList.name)
                        .font(.headline)
                    Spacer()
                }
            }
            .padding(16.7/3)
            .background(RoundedRectangle(cornerRadius: 16.7/2, style: .continuous).fill(Color.black.gradient))
        }
        .buttonStyle(.plain)
        
    }
}

