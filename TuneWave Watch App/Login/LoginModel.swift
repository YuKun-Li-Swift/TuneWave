//
//  LoginModel.swift
//  TuneWave Watch App
//
//  Created by Yukun Li on 2024/6/14.
//

import Foundation
import Alamofire
import SwiftyJSON
import SwiftUI
import SwiftData

//这个类实现了短信验证码登录和手机号登录的功能，会请求登录接口并且将用户信息存储到ModelContext中
@MainActor
@Observable
class YiLoginModel {
    func sendVerificationCode(phoneNumber:String,ctcode:String) async throws {
        if phoneNumber.isEmpty {
            throw VerificationCodeSendError.noPhoneNumber
        }
        if ctcode.isEmpty {
            throw VerificationCodeSendError.noCtCode
        }
        let route = "/captcha/sent"
        let fullURL = baseAPI + route
        let json = try await AF.request(fullURL,parameters: ["phone":phoneNumber,"ctcode":ctcode] as [String:String]).LSAsyncJSON()
        print("sendCode\(json)")
        try json.errorCheck()
    }
    enum VerificationCodeSendError:Error,LocalizedError {
        case noCtCode
        case noPhoneNumber
        var errorDescription: String? {
            switch self {
            case .noPhoneNumber:
                "请输入手机号"
            case .noCtCode:
                "请输入手机号国家区号（中国大陆手机号请输入86）"
            }
        }
    }
    
    func loaginBy(phone:String,countrycode:String,password:String? = nil,captcha:String? = nil,modelContext:ModelContext) async throws {
        let route = "/login/cellphone"
        let fullURL = baseAPI + route
        let json = try await AF.request(fullURL,parameters: {
            if let password {
                ["phone":phone,"password":password,"countrycode":countrycode] as [String:String]
            } else if let captcha {
                ["phone":phone,"captcha":captcha,"countrycode":countrycode] as [String:String]
            } else {
                throw LoginError.noParameter
            }
        }()).LSAsyncJSON()
        try json.errorCheck()
        print("loaginBy\(json)")
        let user = try parseLoginData(json)
        //如果用户同一个账号登录了又退出登录又登录
        //删除现有的用户
        let exsistUser = try CurrentUserFinder().userWith(userID: user.userID, modelContext: modelContext)
        for userNeedDelete in exsistUser {
            modelContext.delete(userNeedDelete)
        }
        //再插入新的用户
        modelContext.insert(user)
        try modelContext.save()
    }
    enum LoginError:Error,LocalizedError {
        case noParameter
        case noEnoughBlank
        var errorDescription: String? {
            switch self {
            case .noParameter:
                "登录失败（字段缺失）"
            case .noEnoughBlank:
                "没有足够的字段"
            }
        }
    }
    func parseLoginData(_ json:JSON) throws -> YiUser {
        let profile = json["profile"]
        guard let token = json["token"].string else {
            throw LoginError.noEnoughBlank
        }
        guard let cookie = json["cookie"].string else {
            throw LoginError.noEnoughBlank
        }
        guard let userId = profile["userId"].int64,let avatarUrl = profile["avatarUrl"].url,let nickname = profile["nickname"].string,let vipType = profile["vipType"].int64 else {
            throw LoginError.noEnoughBlank
        }
        return YiUser(userID: String(userId), nickname: nickname, avatarUrl: avatarUrl.absoluteString, vipType: vipType,token:token,cookie: cookie)
    }
    func logOut(user:YiUser,modelContext:ModelContext) throws {
        modelContext.delete(user)
        try modelContext.save()
        // 调用清理Cookie的函数
        clearCookies()
    }
    func clearCookies() {
        // 获取默认的Cookie存储
        let cookieStorage = HTTPCookieStorage.shared
        
        // 获取所有Cookie
        if let cookies = cookieStorage.cookies {
            // 遍历所有Cookie并删除
            for cookie in cookies {
                cookieStorage.deleteCookie(cookie)
            }
        }
        
        // 打印确认清理后的Cookie
        print("All cookies cleared: \(cookieStorage.cookies?.count ?? 0) cookies left")
    }

}

@MainActor
class LoginRefresher {
    func refreshLogin(for user:YiUser,modelContext:ModelContext) async throws {
        let route = "/login/refresh"
        let fullURL = baseAPI + route
        let json = try await AF.request(fullURL).LSAsyncJSON()
        try json.errorCheck()
        guard let cookie = json["cookie"].string else {
            throw RefreshCookieError.noCookie
        }
        user.cookie = cookie
        try modelContext.save()
        print("刷新Cookie成功")
    }
    enum RefreshCookieError:Error,LocalizedError {
        case noCookie
        var errorDescription: String? {
            switch self {
            case .noCookie:
                "没有Cookie字段"
            }
        }
    }
}

@MainActor
@Observable
class CurrentUserFinder {
    func userWith(userID:String,modelContext:ModelContext) throws -> [YiUser] {
        let predicate = #Predicate<YiUser> { music in
            music.userID == userID
        }
        let fetchDescriptor = FetchDescriptor<YiUser>(predicate: predicate)
        let allResult = try modelContext.fetch(fetchDescriptor)
        return allResult
    }
    func currentActivedUserIfHave(modelContext:ModelContext) throws -> YiUser? {
        let fetchDescriptor = FetchDescriptor<YiUser>()
        let allResult = try modelContext.fetch(fetchDescriptor)
        //后续版本需要支持多用户，如果有多个账号，弹出让用户自己选择
        if let matched = allResult.last {
            return matched
        } else {
            return nil
        }
    }
}

//该视图开源帮助处理加载的状态，方便在页面加载时提供视觉反馈，并且负责统一的错误处理
@MainActor
struct LoadingSkelton<V0:View,V1:View,V2:View>: View {
    var loadingView:()->(V0)
    var successView:()->(V1)
    var errorView:(Error)->(V2)
    var loadingAction:() async throws -> ()
    @State
    private var loaded = false
    @State
    private var stage:loadingStage = loadingStage.loading
    var body: some View {
        ZStack {
            successView()
                .opacity((stage == loadingStage.success) ? 1 : 0)
                .allowsHitTesting((stage == loadingStage.success) ? true : false)
            switch self.stage {
            case .loading:
                loadingView()
                
            case .error(let error):
                errorView(error)
            default:
                EmptyView()
            }
        }
        .task { @MainActor in
            if !loaded {
                loaded = true
                do {
                    try await loadingAction()
                    await MainActor.run {
                        withAnimation(.smooth) {
                            self.stage = .success
                        }
                    }
                } catch {
                    await MainActor.run {
                        withAnimation(.smooth) {
                            self.stage = .error(error)
                        }
                    }
                }
            }
        }
    }
}

struct APIErrorDisplay: View {
    var remoteControlTag:String
    var error:Error
    @State
    var showSheet = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                Text("出错了")
                    .font(.headline)
                Button {
                    self.showSheet = true
                } label: {
                    Text("请点此联系开发者")
                }
                Divider()
                Text("错误报告：")
                Text(error.localizedDescription)
                    .font(.footnote)
            }
        }
        .sheet(isPresented: $showSheet) {
            qrSheet()
        }
    }
    @ViewBuilder
    func qrSheet() -> some View {
        ScrollView {
            Image(.contactQR)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .navigationTitle("手机扫码联系开发者")
        }
    }
}



enum loadingStage:Equatable {
    static func == (lhs: loadingStage, rhs: loadingStage) -> Bool {
        switch lhs {
        case .loading:
            switch rhs {
            case .loading:
                true
            case .success:
                false
            case .error(let error):
                false
            }
        case .success:
            switch rhs {
            case .loading:
                false
            case .success:
                true
            case .error(let error):
                false
            }
        case .error(let error):
            false
        }
    }
    
    case loading
    case success
    case error(Error)
}


extension Alamofire.DataRequest {
    enum asyncResponseError:Error {
        case unknowError
    }
    func LSAsyncJSON() async throws -> JSON {
        try await withUnsafeThrowingContinuation { continuation in
            self.response { response in
                if let data = response.data {
                    let json = JSON(data)
                    continuation.resume(returning: json)
                } else {
                    if let error = response.error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(throwing: asyncResponseError.unknowError)
                    }
                }
            }
        }
    }
}

extension View {
    @ViewBuilder
    func onLoad(perform action: (() -> Void)? = nil) -> some View {
        self
            .modifier(OnLoad(action: action))
    }
}
struct OnLoad: ViewModifier {
    @State
    private var loaded = false
    var action: (() -> Void)? = nil
    func body(content: Content) -> some View {
        content
            .onAppear(perform: {
                if loaded == false {
                    loaded = true
                    if let action {
                        action()
                    }
                }
            })
    }
}

