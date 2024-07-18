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
    var userContainer:YiUserContainer
    @State
    var mod = UserPlayListModel()
    @State
    var vm :MyPlayListViewModel? = nil
    @State
    var leftColumn:[UserPlayListModel.PlayListObj] = []
    @State
    var rightColumn:[UserPlayListModel.PlayListObj] = []
    @State
    var selected:UserPlayListModel.PlayListObj?
    @State
    var whereIsModTimer = Timer.publish(every: 0.1, on: .main, in: .default).autoconnect()
    var body: some View {
        LoadingSkelton {
            ProgressView()
        } successView: {
            VStack {
                if let vm {
                    if vm.playListContainer.playlists.isEmpty {
                        Text("该账号下没有歌单")
                    } else {
                        ScrollView {
                            VStack {
                                HStack(alignment: .center, spacing: 16.7/3) {
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
                                            PlayListGrid(playList: .placeholder(),selected:$selected)
                                                .hidden()
                                        }
                                    }
                                }
                                IgnoreCacheLoadingView(vm: vm)
                            }
                        }
                        .onChange(of: vm.playListContainer, initial: true) { oldValue, newValue in
                            (leftColumn,rightColumn) = vm.rebuildPlayList(origin: newValue.playlists)
                        }
                    }
                } else {
                    NeverErrorView(remoteControlTag: "MyPlayList")
                }
            }
            .navigationDestination(item: $selected) { playlist in
                PlayListDetailPage(playList: playlist)
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

