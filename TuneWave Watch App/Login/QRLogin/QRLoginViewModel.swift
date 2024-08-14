//
//  QRLoginViewModel.swift
//  TuneWave Watch App
//
//  Created by Yukun Li on 2024/8/8.
//

import Foundation
import SwiftUI
import Alamofire
import SwiftyJSON
import EFQRCode
import SwiftData


@MainActor
@Observable
class YiQRLoginModel {
    let actor = YiQRLoginActor()
    var unikey:String? = nil//step1获取这个
    var qr:UIImage? = nil//step2获取这个
    var step3Status:YiQRLoginActor.Status? = nil
    var step3Done = false
    func step1() async throws {
    
        self.unikey = try await actor.getKey()
    }
    func step2() async throws {
        guard let unikey else {
            throw Step2Error.noUnikey
        }
        self.qr = try await actor.getQR(key: unikey)
    }
    enum Step2Error:Error,LocalizedError {
        case noUnikey
        var errorDescription: String? {
            switch self {
            case .noUnikey:
                "调用顺序不正确：请先生成UniKey再调用此接口"
            }
        }
    }
    func checkScanStatus(mod:YiLoginModel,modelContext: ModelContext) {
        if !step3Done {
            Task {
                guard let unikey else {
                    throw Step2Error.noUnikey
                }
                do {
                    
                    
                    let (status,cookie) = try await actor.checkScanStatus(key: unikey, mod: mod)
                    if let status {
                        step3Status = status
                    } else if let cookie {
                        self.step3Done = true
                        try await mod.loginByQR(cookie: cookie, modelContext: modelContext)
                        step3Status = .waitingComfirm//这个再也看不见了，因为会之间跳登录成功的UI
                    } else {
                        step3Status = .unknow("未知错误\n"+DeveloperContactGenerator.generate())
                    }
                } catch {
                    step3Status = .unknow(error.localizedDescription)
                }
            }
        } else {
            print("二维码扫码流程已完成，不再继续轮询")
        }
    }
}

class YiQRLoginActor {
    enum QRLoginError:Error,LocalizedError {
        case noFieldUnikey
        case noFieldQrUrl
        case noCode
        var errorDescription: String? {
            switch self {
            case .noCode:
                "数据结构不匹配：缺少字段code"
            case .noFieldQrUrl:
                "数据结构不匹配：缺少字段data.qrurl"
            case .noFieldUnikey:
                "数据结构不匹配：缺少字段data.unikey"
            }
        }
    }
    func getKey() async throws -> String {
        let route = "/login/qr/key"
        let fullURL = baseAPI + route
        let json = try await AF.request(fullURL,parameters: ["timestamp":String(Int(Date.now.timeIntervalSince1970.rounded()))] as [String:String]).LSAsyncJSON()
        try json.errorCheck()
        guard let unikey = json["data"]["unikey"].string else {
            throw QRLoginError.noFieldUnikey
        }
        return unikey
    }
    //是一个URL，如果有人用微信扫码了，会提示要下网易云
    func getQR(key:String) async throws -> UIImage {
        let route = "/login/qr/create"
        let fullURL = baseAPI + route
        let json = try await AF.request(fullURL,parameters: ["key":key] as [String:String]).LSAsyncJSON()
        try json.errorCheck()
//        print("getQR\(json)")
        guard let qrContent = json["data"]["qrurl"].string else {
            throw Self.QRLoginError.noFieldQrUrl
        }
        let uiimage = try createQRFrom(qrContent)
        return uiimage
    }
    //正常生成二维码用Core Image足矣，但watchOS没有Core Image接口可以用。
    //使用第三方库
    //屏幕上显示的二维码，存在遮挡的可能性：屏幕漏液、出线，使用默认纠错级别即可。
    func createQRFrom(_ string:String) throws -> UIImage {
        guard let qr = EFQRCode.generate(for: string) else {
            throw CreateQRError.unknowReason
        }
        return UIImage(cgImage: qr)
    }
    
    enum CreateQRError:Error,LocalizedError {
        //比如说API出问题了，返回了一条很长的URL
    case unknowReason
        var errorDescription: String? {
            switch self {
            case .unknowReason:
                "二维码登录失败：无法生成二维码,"+DeveloperContactGenerator.generate()
            }
        }
    }
    enum Status:Equatable {
        case waitingScan
        case waitingComfirm
        case canceled//可能是过期了，也可能是用户扫了然后点击取消登录
        case unknow(String)
    }
    func checkScanStatus(key:String,mod:YiLoginModel) async throws -> (Status?,String?) {
        let route = "/login/qr/check"
        let fullURL = baseAPI + route
        let json = try await AF.request(fullURL,parameters: ["key":key,"timestamp":String(Int(Date.now.timeIntervalSince1970.rounded()))] as [String:String]).LSAsyncJSON()
//        print("checkScanStatus\(json)")
        guard let code = json["code"].int64  else {
            throw QRLoginError.noCode
        }
            switch code {
            case 801:
                   return (.waitingScan,nil)
            case 802:
                return (.waitingComfirm,nil)
            case 800:
                return (.canceled,nil)
            case 803:
                if let cookie = json["cookie"].string {
                    return (nil,cookie)
                } else {
                    return  (.unknow(json["message"].string ?? "错误码\(code)"),nil)
                }
            default:
                return  (.unknow(json["message"].string ?? "错误码\(code)"),nil)
            }
        
    }
}
