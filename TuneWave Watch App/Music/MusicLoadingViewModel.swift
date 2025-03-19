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
    var doneLoading = false
    var haveAnyStepError = false
    var isCanceledPlay = false
    var playError:Error? = nil
    
    //0到1之间的值
    var audioDownloadProgress:Double = 0
    var audioDataSize:Double? = nil
    func playMusicWithCached(yiMusic: YiMusic,playList:[PlayListModel.PlayListSong], playerHolder: MusicPlayerHolder,modelContext: ModelContext,preferencedSeekModeRawValue: SeekPreference.RawValue) async {
        do {
            if !isCanceledPlay {
                let playingList = try await OnlineToLocalConverter.convert(onlineSongs: playList, modelContext: modelContext)
                try await playerHolder.playMusic(yiMusic,playingList:playingList, preferencedSeekModeRawValue: preferencedSeekModeRawValue)
                //从缓存加载是View一出现就做的事情，不要动画，给人一种“打开页面音乐就在这儿”的感觉
                showPlayPage()
            }
        } catch {
            self.playError = error
        }
    }
    
    func playMusic(downloadMod: MusicLoader,isOnline:Bool, modelContext: ModelContext, playerHolder: MusicPlayerHolder,playList:[PlayListModel.PlayListSong],preferencedSeekModeRawValue: SeekPreference.RawValue) async {
        do {
            let yiMusic = try await downloadMod.generateFinalMusicObject(isOnline: isOnline)
            modelContext.insert(yiMusic)
            try modelContext.save()
            if !isCanceledPlay {
                let playingList = try await OnlineToLocalConverter.convert(onlineSongs: playList, modelContext: modelContext)
                try await playerHolder.playMusic(yiMusic,playingList:playingList, preferencedSeekModeRawValue: preferencedSeekModeRawValue)
                withAnimation(.smooth) {
                    showPlayPage()
                }
            }
        } catch {
            self.playError = error
        }
    }
    
    func updateHaveAnyStepError() {
        let vm = self
        if (vm.step1Error != nil) || (vm.step2Error != nil) || (vm.step3Error != nil) || (vm.step4Error != nil) {
            self.haveAnyStepError = true
        } else {
            self.haveAnyStepError = false
        }
    }
    enum PlayError:Error,LocalizedError {
    case noDownloadMode
        var errorDescription: String? {
            switch self {
            case .noDownloadMode:
                "缺少了加载模块，"+DeveloperContactGenerator.generate()
            }
        }
    }
}
