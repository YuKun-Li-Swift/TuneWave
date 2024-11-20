//
//  TuneWaveApp.swift
//  TuneWave Watch App
//
//  Created by Yukun Li on 2024/6/12.
//

import SwiftUI

@main
struct TuneWave_Watch_AppApp: App {
    init() {
        //在APP启动的时候清理，避免APP的其它部分正在使用这些Temp文件
        //在主线程执行清理，这样可以保持APP正在启动的界面，直到清理完成
        TempFileCreator.clearTemporaryDirectory()
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(for: [YiUser.self,YiMusic.self])
        }
    }
}
