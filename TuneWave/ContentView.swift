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
        VStack {
            Label("在Apple Watch上使用全部功能", systemImage: "applewatch")
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
