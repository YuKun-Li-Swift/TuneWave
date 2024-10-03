//
//  IgnoreSlient.swift
//  TuneWave
//
//  Created by Yukun Li on 2024/9/14.
//

import SwiftUI

struct IgnoreSlientModeButton: View {
    @Binding
    var pushIgnoreSlientModePage:Bool
    var body: some View {
        Button {
            pushIgnoreSlientModePage = true
        } label: {
            Label("外放设置", systemImage: "applewatch.radiowaves.left.and.right")
        }
    }
}

struct IgnoreSlientModeView: View {
    @AppStorage("ignore Silent Mode")
    private var ignoreSlientMode = true
    var body: some View {
        List {
            Text("当静音模式打开时，是否外放声音")
                .bold()
                .listRowBackground(EmptyView())
            Button {
                ignoreSlientMode = true
            } label: {
                HStack {
                    Text("是")
                    Spacer()
                    if ignoreSlientMode {
                        Image(systemName: "checkmark")
                            .transition(.blurReplace)
                    }
                }
            }
            Button {
                ignoreSlientMode = false
            } label: {
                VStack(alignment: .leading) {
                    HStack {
                        Text("否")
                        Spacer()
                        if ignoreSlientMode == false {
                            Image(systemName: "checkmark")
                                .transition(.blurReplace)
                        }
                    }
                    if ignoreSlientMode == false {
                        Text("如果您忘记把静音模式关掉了，在没连耳机时，就算音量开到最大也听不到声音")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .animation(.smooth, value: ignoreSlientMode)
        .accessibilityRepresentation {
            Toggle("当静音模式打开时，是否外放声音", isOn: $ignoreSlientMode)
        }
    }
}
