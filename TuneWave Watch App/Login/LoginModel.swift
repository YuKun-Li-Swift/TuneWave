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
import os

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
        let json = try await AFTW.request(fullURL,parameters: ["phone":phoneNumber,"ctcode":ctcode] as [String:String]).LSAsyncJSON()
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
    
    func loginByQR(cookie:String,modelContext:ModelContext) async throws {
        print("二维码登录得到的cookie："+cookie)
        let route = "/login/status"
        let fullURL = baseAPI + route
        let json = try await AFTW.request(fullURL,parameters:["cookie":cookie] as [String:String]).LSAsyncJSON()
        try json.errorCheck()
        print("loaginBy\(json)")
        let user = try YiLoginModel.parseQRLoginData(json,cookie:cookie)
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
    
    func loaginBy(phone:String,countrycode:String,password:String? = nil,captcha:String? = nil,modelContext:ModelContext) async throws {
        let route = "/login/cellphone"
        let fullURL = baseAPI + route
        let json = try await AFTW.request(fullURL,parameters: {
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
    static
    func parseQRLoginData(_ json:JSON,cookie:String) throws -> YiUser {
        let profile = json["data"]["profile"]
        let token = ""//就像数据结构里说明的那样，通过QR登录的，这个字段是空字符串
        guard let userId = profile["userId"].int64,let avatarUrl = profile["avatarUrl"].url,let nickname = profile["nickname"].string,let vipType = profile["vipType"].int64 else {
            throw LoginError.noEnoughBlank
        }
        return YiUser(userID: String(userId), nickname: nickname, avatarUrl: avatarUrl.absoluteString, vipType: vipType,token:token,cookie: cookie)
    }
    
    //token和cookie就用老的
    static
    func parseUserInfo(_ json:JSON,token:String,cookie:String) throws -> YiUser {
        let profile = json["profile"]
        let cookie = cookie
        guard let userId = profile["userId"].int64,let avatarUrl = profile["avatarUrl"].url,let nickname = profile["nickname"].string,let vipType = profile["vipType"].int64 else {
            throw LoginError.noEnoughBlank
        }
        return YiUser(userID: String(userId), nickname: nickname, avatarUrl: avatarUrl.absoluteString, vipType: vipType,token:token,cookie: cookie)
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
class PersonInfoRefresher {
    func refreshLogin(for user:YiUser,modelContext:ModelContext) async throws {
        let cookie = user.cookie
        if cookie.isEmpty {
            throw RefreshPersonInfoError.noCookie
        }
        let route = "/user/detail"
        let fullURL = baseAPI + route
        let json = try await AFTW.request(fullURL,parameters:["uid":user.userID,"cookie":cookie] as [String:String]).LSAsyncJSON()
        try json.errorCheck()
//        print("refreshingLoginBy\(json)")
        let newUserInfo = try YiLoginModel.parseUserInfo(json,token:user.token,cookie:cookie)
        user.refreshInfo(nickname: newUserInfo.nickname, avatarUrl: newUserInfo.avatarUrl, vipType: newUserInfo.vipType, token: newUserInfo.token, cookie: newUserInfo.cookie)
        try modelContext.save()
        print("刷新用户信息成功")
    }
    enum RefreshPersonInfoError:Error,LocalizedError {
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
class LoginRefresher {
    
    ///向网易云服务器请求新的cookie，让服务器知道客户端有在每天登录
    func refreshLogin(for user:YiUser,modelContext:ModelContext) async throws {
            let route = "/login/refresh"
            let fullURL = baseAPI + route
            let json = try await AFTW.request(fullURL,parameters: ["cookie":user.cookie] as [String:String]).LSAsyncJSON()
            try json.errorCheck(outputBodyIfError: false)
            guard let cookie = json["cookie"].string else {
                throw RefreshCookieError.noCookie
            }
            //新的cookie不用存下来，请求这个接口只是让服务器知道“老cookie我还在用”
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
        let predicate = #Predicate<YiUser> { user in
            user.userID == userID
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
        .onLoad {
            Task {
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
            .scenePadding(.horizontal)
        }
        .alert(DeveloperContactGenerator.generate(), isPresented: $showSheet) { }
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
//                    if let string = String(data: data, encoding: .utf8) {
//                        os_log("\(string)")
//                    }
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



