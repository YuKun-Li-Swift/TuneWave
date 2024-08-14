//
//  YiUserContainer.swift
//  TuneWave Watch App
//
//  Created by Yukun Li on 2024/7/15.
//

import SwiftUI
import SwiftData

//因为让YiUser直接满足@Observable不行，就包装一层
@Observable
class YiUserContainer:Equatable {
    var id = UUID()
    static func == (lhs: YiUserContainer, rhs: YiUserContainer) -> Bool {
        lhs.id == rhs.id
    }
    
    var activedUser:YiUser
    init(activedUser: YiUser) {
        self.activedUser = activedUser
    }
}

@Model
class YiUser {
    var id = UUID()
    //这个字段登录以外的地方没用到，并且在（少数）验证码登录和（多数）二维码登录的时候，是空字符串
    @Attribute(.allowsCloudEncryption)
    var token:String
    @Attribute(.allowsCloudEncryption)
    var cookie:String
    var userID:String
    var nickname:String
    var avatarUrl:String
    var vipType:Int64
    init(id: UUID = UUID(), userID: String, nickname: String, avatarUrl: String, vipType: Int64,token:String,cookie:String) {
        self.id = id
        self.userID = userID
        self.nickname = nickname
        self.avatarUrl = avatarUrl
        self.vipType = vipType
        self.token = token
        self.cookie = cookie
    }
    func refreshInfo(nickname: String, avatarUrl: String, vipType: Int64,token:String,cookie:String) {
        self.nickname = nickname
        self.avatarUrl = avatarUrl
        self.vipType = vipType
        self.token = token
        self.cookie = cookie
    }
}
