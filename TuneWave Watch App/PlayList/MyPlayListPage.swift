//
//  MyPlayList.swift
//  TuneWave Watch App
//
//  Created by Yukun Li on 2024/7/9.
//

import SwiftUI
let screen = WKInterfaceDevice.current().screenBounds


//抽象出2列的Grid
//圆角图片
//按钮容器border样式
//增加显式视图id
//增加左右边距
@MainActor
struct MyPlayList: View {
    @Environment(YiUserContainer.self)
    var userContainer:YiUserContainer
    @State
    var mod = PlayListModel()
    @State
    var vm :MyPlayListViewModel? = nil
    @State
    var leftColumn:[PlayListModel.PlayListObj] = []
    @State
    var rightColumn:[PlayListModel.PlayListObj] = []
    @State
    var selected:PlayListModel.PlayListObj?
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
                            
                            HStack(alignment: .center, spacing: 16.7/3) {
                                VStack(alignment: .center, spacing: 16.7/3) {
                                    ForEach(leftColumn) { i in
                                        PlayListGrid(playList: i,selected:$selected)
                                    }
                                }
                                VStack(alignment: .center, spacing: 16.7/3) {
                                    if !rightColumn.isEmpty {
                                        ForEach(rightColumn) { i in
                                            PlayListGrid(playList: i,selected:$selected)
                                        }
                                    } else {
                                        //如果新号只有一个歌单
                                        //占位，不然布局不对了
                                        PlayListGrid(playList: .placeholder(),selected:$selected)
                                            .hidden()
                                    }
                                }
                            }
                        }
                        .onChange(of: vm.playListContainer, initial: true) { oldValue, newValue in
                            (leftColumn,rightColumn) = rebuildPlayList(origin: newValue.playlists)
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
            let playListParsed = try await mod.getMyPlayList(user: user)
            let newVM = MyPlayListViewModel(playList: playListParsed)
            self.vm = newVM
        }
    }
    func rebuildPlayList(origin:[PlayListModel.PlayListObj]) -> (left:[PlayListModel.PlayListObj],right:[PlayListModel.PlayListObj]) {
        var left:[PlayListModel.PlayListObj] = []
        var right:[PlayListModel.PlayListObj] = []
        for (index,i) in origin.enumerated() {
            let reamain = index % 2
            switch reamain {
            case 0:
                left.append(i)
            case 1:
                right.append(i)
            default:
                fatalError("不可能——数学有问题")
            }
        }
        return (left,right)
    }
}
import SDWebImageSwiftUI

struct PlayListGrid: View {
    
    @State
    var playList:PlayListModel.PlayListObj
    @Binding
    var selected:PlayListModel.PlayListObj?
    var body: some View {
        Button {
            selected = playList
        } label: {
            VStack(alignment: .center, spacing: 16.7/2) {
                if let url = playList.coverImgUrl {
                    WebImage(url: url.lowRes(xy2x: Int(screen.width)), transaction: .init(animation: .smooth)) { phase in
                        switch phase {
                        case .empty:
                            Rectangle()
                                .fill(.clear)
                                .aspectRatio(1, contentMode: .fit)
                                .overlay(alignment: .center) {
                                    Image(systemName: "photo.badge.arrow.down")
                                        .imageScale(.large)
                                }
                                .transition(.blurReplace.animation(.smooth))
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .transition(.blurReplace.animation(.smooth))
                                .clipShape(RoundedRectangle(cornerRadius: 16.7/3, style: .continuous))
                        case .failure(let error):
                            Image(systemName: "wifi.exclamationmark")
                                .imageScale(.large)
                                .transition(.blurReplace.animation(.smooth))
                        }
                    }
                } else {
                    Image(systemName: "photo")
                        .imageScale(.large)
                        .transition(.blurReplace.animation(.smooth))
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

