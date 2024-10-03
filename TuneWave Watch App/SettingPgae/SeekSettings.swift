//
//  SeekSettings.swift
//  TuneWave
//
//  Created by Yukun Li on 2024/9/29.
//

import SwiftUI

struct SeekSettingsView: View {
    @Environment(MusicPlayerHolder.self)
    private var playerHolder:MusicPlayerHolder
    @AppStorage("PreferencedSeekMode")
    private var preferencedSeekModeRawValue:SeekPreference.RawValue = SeekPreference.song.rawValue//默认显示上一首下一首按钮
    var body: some View {
        List {
            Picker(selection: $preferencedSeekModeRawValue) {
                Text("快进快退按钮")
                    .tag(SeekPreference.second.rawValue)
                VStack(alignment: .leading) {
                    Text("上一首下一首按钮（默认）")
                    Text("即切歌按钮")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .tag(SeekPreference.song.rawValue)
            } label: {
                Text("按钮模式")
            }
            .pickerStyle(.navigationLink)
        }
        .navigationTitle("按钮模式")
        .onChange(of: preferencedSeekModeRawValue, initial: false) { oldValue, newValue in
            playerHolder.updateNowPlay(preferencedSeekModeRawValue: preferencedSeekModeRawValue)
        }
    }
}

enum SeekPreference:Int {
    case second = 188//+10s / -10s
    case song = 145//上一首 / 下一首
}
