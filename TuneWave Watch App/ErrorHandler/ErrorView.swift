//
//  ErrorView.swift
//  TuneWave Watch App
//
//  Created by Yukun Li on 2024/7/15.
//

import SwiftUI

///确保我包裹在ScrollView或者ScrollViewOrNot中
struct ErrorView: View {
    var errorText:String
    var body: some View {
        VStack {
            Text("出错了：")
                .font(.headline)
            Divider()
            Text(errorText)
                .foregroundStyle(.secondary)
        }
        .scenePadding(.horizontal)
        .transition(.blurReplace)
    }
}

struct ErrorViewWithCustomTitle: View {
    var title:String
    var errorText:String
    var body: some View {
        VStack {
            Text(title)
                .font(.headline)
            Divider()
            Text(errorText)
                .foregroundStyle(.secondary)
        }
        .transition(.blurReplace)
    }
}

struct ErrorViewWithListInlineStyle: View {
    var title:String
    var errorText:String
    @State
    private var showFullPage = false
    var body: some View {
        Button {
            showFullPage = true
        } label: {
            VStack {
                Text(title)
                    .font(.headline)
                Divider()
                Text(errorText)
                    .foregroundStyle(.secondary)
                    .font(.footnote)
                    .lineLimit(1)
            }
            .transition(.blurReplace)
            
        }
        .sheet(isPresented: $showFullPage, content: {
            ScrollView {
                VStack {
                    Text(errorText)
                }
                .navigationTitle("出错了")
                .scenePadding(.horizontal)
            }
        })
    }
}
