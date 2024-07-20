//
//  MusicLoadingViewModel.swift
//  TuneWave Watch App
//
//  Created by Yukun Li on 2024/7/15.
//

import Foundation
import SwiftUI
import SwiftData

//通过这个视图模型，来管理加载一首歌的4个步骤，并且精细到每一个步骤的执行情况（是否完成、是否出错）
@MainActor
@Observable
class MusicLoadingViewModel {
    var showPlayPage:()->() = {}
    var step1Done = false
    var step1Error:String? = nil
    var step2Done = false
    var step2Error:String? = nil
    var step3Done = false
    var step3Error:String? = nil
    var step4Done = false
    var step4Error:String? = nil
    var isCanceledPlay = false
    var playError:Error? = nil
    
    //0到1之间的值
    var audioDownloadProgress:Double = 0
    var audioDataSize:Double? = nil
    func playMusicWithCached(yiMusic: YiMusic, playerHolder: MusicPlayerHolder) {
        do {
            if !isCanceledPlay {
                try playerHolder.playMusic(yiMusic)
                //从缓存加载是View一出现就做的事情，不要动画，给人一种“打开页面音乐就在这儿”的感觉
                showPlayPage()
            }
        } catch {
            self.playError = error
        }
    }
    
    func playMusic(downloadMod: MusicLoader, modelContext: ModelContext, playerHolder: MusicPlayerHolder) async {
        do {
            let yiMusic = try await downloadMod.generateFinalMusicObject()
            modelContext.insert(yiMusic)
            try modelContext.save()
            if !isCanceledPlay {
                try playerHolder.playMusic(yiMusic)
                withAnimation(.smooth) {
                    showPlayPage()
                }
            }
        } catch {
            self.playError = error
        }
    }
}
