//
//  BatchDownloadRow.swift
//  TuneWave
//
//  Created by Yukun Li on 2024/9/25.
//

import SwiftUI

struct BatchDownloadRow: View {
    @State
    var downloadTask:DownloadTask
    @State
    private var showError:ErrorStringPack? = nil
    struct ErrorStringPack:Identifiable {
        var id = UUID()
        var errorString:String
    }
    var body: some View {
        let music = downloadTask.music
        MusicRowSingleLine(tapAction: {
            //仅仅用于在下载失败的时候查看错误详情，批量下载只能等待程序一首首下载，不允许点击暂停/继续，不允许点击以优先下载
            if case .failed(let errorString) = downloadTask.status {
                showError = .init(errorString: errorString)
            }
        }, imageURL: .constant(music.imageURL), name: music.name, hightlight: .constant(false),attatchView:{
            VStack(content: {
                let message:String = {
                    switch downloadTask.status {
                    case .waiting:
                        return ("等待下载")
                    case .downloading:
                        return ("下载中……")
                    case .done:
                        return ("下载完成")
                    case .failed(let _):
                        return ("下载失败，点此了解原因")
                    }
                }()
                Text(message)
                    .contentTransition(.numericText()).animation(.smooth)
            })
            .padding(.vertical,6)
                .foregroundStyle(.secondary)
        })
        .sheet(item: $showError) { errorStringPack in
            ScrollView {
                Text(errorStringPack.errorString)
                    .multilineTextAlignment(.center)
                Button("好", action: {
                    showError = nil
                })
            }
            .navigationTitle("下载失败原因")
        }
    }
}
