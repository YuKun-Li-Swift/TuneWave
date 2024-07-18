//
//  SettingPage.swift
//  TuneWave Watch App
//
//  Created by Yukun Li on 2024/7/15.
//

import SwiftUI

struct SettingPage: View {
    var body: some View {
        Button {
            //删除isOnline的YiMusic
            //删除SDWebImage的图片缓存
            //删除Alamofire的Session缓存
        } label: {
            Label("清理空间", systemImage: "trash.fill")
        }
        .alert("除了您在app登录的账号，和下载列表中的音乐，其余所有缓存都将被清理。清理后您将会遇到：歌单页面加载时间变慢，因为它们的缓存被清理掉了；音乐播放加载时间变长，因为它们的缓存被清理掉了", isPresented: .constant(true)) {
            
        }

    }
}

#Preview {
    SettingPage()
}
