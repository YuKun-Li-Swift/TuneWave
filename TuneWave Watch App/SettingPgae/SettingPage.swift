//
//  SettingPage.swift
//  TuneWave Watch App
//
//  Created by Yukun Li on 2024/7/15.
//

import SwiftUI
import SwiftData

struct SettingPageNavigationLink: ViewModifier {
    @Binding
    var openSettingPage:Bool
    @Binding
    var openOfflineCleaner:UUID
    @Environment(MusicPlayerHolder.self)
    private var musicHolder
    func body(content: Content) -> some View {
        content
            .navigationDestination(isPresented: $openSettingPage, destination: {
                SettingPage(openOfflineCleaner:$openOfflineCleaner)
                    .environment(musicHolder)
            })
    }
}

struct SettingPage: View {
    @Binding
    var openOfflineCleaner:UUID
    @State
    private var pushCleanerPage = false
    @State
    private var pushSeekSettingsPage = false
    @State
    private var pushIgnoreSlientModePage = false
    @State
    private var openOfflineCleanerInner = UUID()
    @State
    private var ignoreSlientModel = IgnoreSlientModeModel()
    @AppStorage("ignore Silent Mode")
    private var ignoreSlientMode = true
    @Environment(MusicPlayerHolder.self)
    private var musicHolder
    var body: some View {
        ScrollView {
            VStack {
                Button {
                    pushCleanerPage = true
                } label: {
                    Label("清理空间", systemImage: "trash.fill")
                }
                Button {
                    pushSeekSettingsPage = true
                } label: {
                    Label("按钮模式", systemImage: "gauge.open.with.lines.needle.33percent.and.arrowtriangle.from.0percent.to.50percent")
                }
            }
        }
        .navigationDestination(isPresented: $pushCleanerPage, destination: {
            CleanerView(openOfflineCleaner: $openOfflineCleanerInner)
                .environment(musicHolder)
        })
        .navigationDestination(isPresented: $pushSeekSettingsPage, destination: {
            SeekSettingsView()
        })
        .onChange(of: openOfflineCleaner, initial: false) { oldValue, newValue in
            if oldValue != newValue {
                Task {
                    pushCleanerPage = true
                    try? await Task.sleep(for: .seconds(0.1))
                    openOfflineCleanerInner = UUID()
                }
            }
        }
        .navigationDestination(isPresented: $pushIgnoreSlientModePage, destination: {
            IgnoreSlientModeView()
        })
        .onChange(of: pushIgnoreSlientModePage, initial: false) { oldValue, pushed in
            if pushed {
                ignoreSlientModel.ignoreModeWhenEnter = ignoreSlientMode
            } else {
                ignoreSlientModel.handleAlert(ignoreModeWhenExit: ignoreSlientMode)
            }
        }
        //因为APP打开的时候才会正确设置音频模式，而且因为我不知道默认的音频模式是什么，一旦打开的时候设为了playback，现在也不方便设回去。而且似乎在播放过程中改变音频模式，会不生效，导致还是无法正常在后台播放声音。
        .alert("更变此设置需要重启APP以生效", isPresented: $ignoreSlientModel.showAlert, actions: { Button("重启APP", action: { exit(0) }) })
    }
}

@MainActor
@Observable
class IgnoreSlientModeModel {
    var ignoreModeWhenEnter:Bool? = nil
    var showAlert = false
    func handleAlert(ignoreModeWhenExit:Bool) {
        guard let ignoreModeWhenEnter else {
#if DEBUG
            fatalError("不应该在页面关闭的时候还没有赋值这个")
#endif
            return
        }
        if ignoreModeWhenEnter != ignoreModeWhenExit {
            showAlert = true
        }
    }
}
