//
//  SwiftUIExtension.swift
//  TuneWave Watch App
//
//  Created by Yukun Li on 2024/6/16.
//

import SwiftUI

//设计的时候是按照模拟器上的屏幕尺寸、默认的字体大小设计的，但是实际使用的时候，用户可能会走更小屏幕的设备上运行、在更大的系统字体上运行
//通过这个灵活的切换，当按照设计无法显示完全的时候，就自动包裹进ScrollView来确保能够显示完全
struct ScrollViewOrNot<V:View>: View {
    var content:() -> (V)
    var body: some View {
        ViewThatFits(in: .vertical) {
            content()
            ScrollView {
                content()
            }
        }
    }
}

//为任何SFSymbol创建Slash变体
struct HomeMakeSlashSymbol: View {
    var symbolName:String
    var accessibilityLabel:String
    var body: some View {
        ZStack {
            Image(systemName: symbolName)
            Image(systemName: "line.diagonal")
                .rotationEffect(.degrees(90), anchor: .center)
        }
        .accessibilityLabel(Text(accessibilityLabel))
    }
}

