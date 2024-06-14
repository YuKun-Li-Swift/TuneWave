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
        VStack {
            Label("在Apple Watch上使用全部功能", systemImage: "applewatch")
            //显示操作教程视频
            VideoPlayer(player: nil)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
