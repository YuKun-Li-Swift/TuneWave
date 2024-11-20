//
//  AboutPage.swift
//  TuneWave Watch App
//
//  Created by Yukun Li on 2024/7/15.
//

import SwiftUI

struct AboutPage: View {
    @State
    var showGitHubQR = false
    @State
    var showThridLibraryPage = false
    var body: some View {
        ScrollView {
            Text("本app开源")
            Button {
                showGitHubQR = true
            } label: {
                VStack(alignment: .leading) {
                    Text("项目地址")
                    Text(String("https://github.com/YuKun-Li-Swift/TuneWave"))
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                }
            }
            
            Button {
                showThridLibraryPage = true
            } label: {
                Label("第三方软件包引用", systemImage: "cube.box")
            }
        }
        .navigationDestination(isPresented: $showThridLibraryPage, destination: {
            ThirdPartPackage()
        })
        .navigationDestination(isPresented: $showGitHubQR, destination: {
            Image(.githubQR)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .navigationTitle("扫码查看源代码")
        })
    }
}
struct ThirdPartPackage: View {
    var body: some View {
        List {
            ThirdPartPackageRow(use: "音乐解析", url: "https://gitlab.com/Binaryify/neteasecloudmusicapi")
            ThirdPartPackageRow(use: "动态背景", url: "https://github.com/yamoridon/ColorThiefSwift")
            ThirdPartPackageRow(use: "LRC歌词解析", url: "https://github.com/jayasme/SpotlightLyrics")
            ThirdPartPackageRow(use: "图片显示器", url: "https://github.com/SDWebImage/SDWebImageSwiftUI")
            ThirdPartPackageRow(use: "JSON数据解析", url: "https://github.com/SwiftyJSON/SwiftyJSON")
            ThirdPartPackageRow(use: "网络请求", url: "https://github.com/Alamofire/Alamofire")
        }
        .navigationTitle("软件包引用")
    }
}
struct ThirdPartPackageRow: View {
    var use:String
    var url:String
    var body: some View {
        VStack(alignment: .leading) {
            Text(use)
            Text(url)
                .foregroundStyle(.secondary)
                .font(.footnote)
        }
    }
}

#Preview {
    ThirdPartPackage()
}
#Preview {
    AboutPage()
}
