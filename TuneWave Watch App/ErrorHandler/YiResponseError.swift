//
//  YiResponseError.swift
//  TuneWave Watch App
//
//  Created by Yukun Li on 2024/7/15.
//

import Foundation
import SwiftyJSON

extension JSON {
    func errorCheck() throws {
        func switchCode(_ code:Int64) throws {
            switch code {
            case 301:
                throw YiResponseError.code301
            default:
                try extractMessage()
                throw YiResponseError.responseCodeNot200
            }
        }
        func extractMessage() throws {
            if let message = self["message"].string {
                throw YiResponseError.codeNot200(message)
            }
        }
        if let code = self["code"].int64 {
            if code == 200 {
                return
            } else {
                try switchCode(code)
            }
        } else
        if let code = self["data"]["code"].int64 {
            if code == 200 {
                return
            } else {
             try switchCode(code)
            }
        } else {
            throw YiResponseError.responseCodeNot200
        }
    }
}

enum YiResponseError:Error,LocalizedError {
    case responseCodeNot200
    case code301
    case codeNot200(String)
    var errorDescription: String? {
        switch self {
        case .codeNot200(let message):
            message
        case .responseCodeNot200:
            "网络请求出错（code不为200）"
        case .code301:
            "网络请求出错（未收到登录信息）"
        }
    }
}
