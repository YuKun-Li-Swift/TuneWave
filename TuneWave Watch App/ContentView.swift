//
//  ContentView.swift
//  TuneWave Watch App
//
//  Created by Yukun Li on 2024/6/12.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            NavigationStack {
                VStack {
                    NavigationLink(destination: {
                        
                    }) {
                        Label("登录网易云账号", systemImage: "person.fill.badge.plus")
                    }
                }
                .navigationTitle("悦音音乐")
            }
        }
    }
}

#Preview {
    ContentView()
}
