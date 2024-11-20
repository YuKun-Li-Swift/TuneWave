//
//  AudioSession.swift
//  TuneWave
//
//  Created by Yukun Li on 2024/10/17.
//

import SwiftUI
import Combine
import AVFAudio

//放在APP首页，用户可以看到当前的音量，也方便调音量
struct VolumeButton: View {
    let pushPage:()->()
    let audioSession = AVAudioSession.sharedInstance()
    @State
    private var volume:Double? = nil
    var body: some View {
        Button(action:pushPage) {
            if let volume {
                Label("音量"+String(format: "%.0f", (volume*100).rounded())+"%", systemImage: "speaker.3.fill")
                    .contentTransition(.numericText(value: volume))
                    .transition(.blurReplace.animation(.smooth))
            } else {
                Label("调音量", systemImage: "speaker.3.fill")
                    .transition(.blurReplace.animation(.smooth))
            }
        }
        .onLoad {
            updateCurrentVolume()
        }
        .onReceive(audioSession.publisher(for: \.outputVolume)) { _ in
            updateCurrentVolume()
        }
    }
    func updateCurrentVolume() {
        withAnimation(.smooth) {
            volume = Double(audioSession.outputVolume)
        }
    }
}

//用户首次使用的时候，需要弹窗告诉用户，静音模式开关不会控制音乐音量
struct ExternalSpeakerAlert: ViewModifier {
    @AppStorage("userKnownSlientModeNoControl")//用户已经知晓静音模式开关不会控制音乐音量
    private var userKnownSlientModeNoControl = false
    @State
    private var showAlert = false
    func body(content: Content) -> some View {
        content
            .onAppear {
                if userKnownSlientModeNoControl == false {
                    showAlert = true
                }
            }
            .alert("注意音量！\n您需要在悦音音乐中单独调音量，光是在系统设置里开静音不会让悦音音乐静音。", isPresented: $showAlert) {
                Button("已了解") {
                    userKnownSlientModeNoControl = true
                }
            }
    }
}
