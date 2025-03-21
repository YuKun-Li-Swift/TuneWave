//
//  UserInfoView.swift
//  TuneWave Watch App
//
//  Created by Yukun Li on 2024/7/16.
//

import SwiftUI

//
//  UserInfoPage.swift
//  TuneWave Watch App
//
//  Created by Yukun Li on 2024/7/16.
//

import SwiftUI
import SwiftData
import SDWebImageSwiftUI

@MainActor
struct UserInfoView: View {
    var showLogoutSuccessAlert:()->()
    @State
    var selectedTab:UserInfoViewModel.Tabs = .tab0
    @State
    var userContainer:YiUserContainer
    @State
    var mod = YiLoginModel()
    @Environment(\.modelContext)
    var modelContext
    @State
    var vm = UserInfoViewModel()
    
    var body: some View {
        TabView(selection: $selectedTab,content: {
            VStack(spacing: 12.3) {
                UserPicView(userContainer: userContainer)
                Text(userContainer.activedUser.nickname)
                    .font(.title3).bold()
                UserInfoVIPBadge(vipLevel: userContainer.activedUser.vipType)
            }
            .padding(.bottom, 8.8)
            .ignoresSafeArea(edges: .bottom)
            .tag(UserInfoViewModel.Tabs.tab0)
            VStack {
                Button("退出登录", role: .destructive) {
                    vm.logOutSheet = true
                }
                .alert("确认退出登录吗？", isPresented: $vm.logOutSheet) {
                    Button("确认退出", role: .destructive) {
                        vm.logoutAction(userContainer: userContainer, mod: mod, modelContext: modelContext,onSuc: showLogoutSuccessAlert)
                    }
                    Button("取消", role: .cancel) {

                    }
                }
                .sheet(isPresented: $vm.logOutErrorSheet, content: {
                    ScrollViewOrNot {
                        ErrorView(errorText: vm.logOutError ?? "未知错误")
                    }
                })
            }
            .tag(UserInfoViewModel.Tabs.tab1)
        })
        .onLoad {
            vm.refreshInfo(for: userContainer.activedUser, modelContext: modelContext)
        }
        .tabViewStyle(.verticalPage)
        .navigationTitle("已登录账号")
    }
}



struct UserPicView: View {
    @State
    var userContainer:YiUserContainer
    @State
    var url:URL?
    @State
    var failedAvatar = false
    var body: some View {
        VStack(content: {
            if let url {
                WebImage(url: url.lowRes(xy2x: Int(screen.width*2)), transaction: .init(animation: .smooth)) { phase in
                    switch phase {
                    case .empty:
                        PlaceHolderAvatarImage()
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .transition(.blurReplace.animation(.smooth))
                            .clipShape(Circle())
                    case .failure(let error):
                        PlaceHolderAvatarImage()
                    }
                }
            } else if failedAvatar {//这边也可以放一个显式的错误提示View
                PlaceHolderAvatarImage()
            } else {
                PlaceHolderAvatarImage()
            }
        })
        .frame(maxWidth: 100, maxHeight: 100)
        .onAppear {
            let url:String = userContainer.activedUser.avatarUrl
            if let url = URL(string: url) {
                self.url = url
            } else {
                print("头像url转换出错")
                failedAvatar = true
            }
        }
    }
}

struct PlaceHolderAvatarImage: View {
    var body: some View {
        Image(systemName: "person.circle.fill")
            .resizable()
            .aspectRatio(1, contentMode: .fit)
            .foregroundStyle(Color.gray.gradient)
            //把person区域填充成白色，好看点
            .background(Circle().fill(Color.white).padding())
            .transition(.blurReplace.animation(.smooth))

    }
}

struct UserInfoVIPBadge: View {
    var vipLevel:Int64
    var body: some View {
        switch vipLevel {
        case 11:
            Text("黑胶VIP")
                .padding()
                .background(Capsule().fill(Color.brown.gradient))
        case 0:
            Text("未开通会员")
                .padding()
                .background(Capsule().fill(Color.gray.gradient))
        default:
            Text("会员等级：\(vipLevel)")
                .padding()
                .background(Capsule().fill(Color.brown))
        }
    }
}



@MainActor
@Observable
class UserInfoViewModel {
    let refersher = PersonInfoRefresher()
    var logOutSheet = false
    var logOutError:String? = nil
    var logOutErrorSheet = false
    
    func logoutAction(userContainer:YiUserContainer,mod:YiLoginModel,modelContext:ModelContext,onSuc:()->()) {
        logOutErrorSheet = false
        logOutError = nil
        do {
            try mod.logOut(user: userContainer.activedUser, modelContext: modelContext)
            onSuc()
        } catch {
            self.logOutError = error.localizedDescription
            self.logOutErrorSheet = true
        }
    }
    func refreshInfo(for user: YiUser,modelContext: ModelContext) {
        Task {
            do {
                try await refersher.refreshLogin(for: user, modelContext: modelContext)
            } catch {
                //刷新是静默操作，失败了不用提示，除非在调试
                #if DEBUG
                fatalError("请调查错误："+error.localizedDescription)
                #endif
            }
        }
    }
    enum Tabs {
        case tab0
        case tab1
    }
}
