//
//  ContentView.swift
//  TuneWave
//
//  Created by Yukun Li on 2024/6/12.
//

import SwiftUI
import AVKit
import AVFoundation

struct ContentView: View {
    var body: some View {
        V2HomeView()
            .onLoad {
                Task {
                    //触发网络权限弹弹窗
                    try? await URLSession.shared.data(for: URLRequest(url: URL(string: baseAPI)!))
                }
            }
    }
}

struct V1HomeView: View {
    var body: some View {
        Label("Continue on Apple Watch", systemImage: "applewatch")
            .font(.largeTitle.bold())
            .padding()
    }
}

struct V2HomeView: View {
    var body: some View {
        VStack(spacing:20) {
            Label("在Apple Watch上使用全部功能", systemImage: "applewatch")
            Text("Apple Watch需要watchOS 10.0或更高系统版本")
                .font(.footnote)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
