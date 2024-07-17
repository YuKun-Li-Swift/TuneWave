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
        .sheet(isPresented: $showGitHubQR, content: {
            Image(.githubQR)
                .resizable()
                .aspectRatio(contentMode: .fit)
        })
        .navigationDestination(isPresented: $showThridLibraryPage, destination: {
            ThirdPartPackage()
        })
    }
}
struct ThirdPartPackage: View {
    var body: some View {
        List {
            ThirdPartPackageRow(use: "歌词解析", url: "https://github.com/jayasme/SpotlightLyrics")
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
