//
//  SwiftUIExtension.swift
//  TuneWave Watch App
//
//  Created by Yukun Li on 2024/6/16.
//

import SwiftUI

//设计的时候是按照模拟器上的屏幕尺寸、默认的字体大小设计的，但是实际使用的时候，用户可能会走更小屏幕的设备上运行、在更大的系统字体上运行
//通过这个灵活的切换，当按照设计无法显示完全的时候，就自动包裹进ScrollView来确保能够显示完全
@available(watchOS 10,iOS 16,*)
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


//为了在隐藏导航栏的时候还能有一个返回按钮，同时相比原版按钮增加了弥散光质感的毛玻璃
//确保容器最左上角对准了页面左上角
struct LightCancelButton: View {
    var symbolName:String
    var accessbilityLabel:String
    var action:()->()
    var body: some View {
        LightToolbarButton(symbolName: symbolName, accessbilityLabel: accessbilityLabel, action: action)
        .position(x: 27.5, y: 30)
    }
}

struct LightToolbarButton: View {
    var symbolName:String
    var accessbilityLabel:String
    let cirlce = 32.0//圆的边界框
    let squre = 22.63//内部icon的边界框
    var action:()->()
    var body: some View {
        Button {
            action()
        } label: {
            ZStack {
                Image(systemName: symbolName)
                    .frame(width: squre, height: squre, alignment: .center)
                Circle()
                    .fill(Material.ultraThin)
                    .brightness(-0.23)
                    .colorScheme(.light)
                Image(systemName: symbolName)
                    .frame(width: squre, height: squre, alignment: .center)
            }
        }
        .buttonStyle(.plain)
        .frame(width: cirlce, height: cirlce, alignment: .center)
        .accessibilityLabel(Text(accessbilityLabel))
    }
}

struct FourLineHeightPlaceholder: View {
    var body: some View {
        VStack(content: {
            HStack {
                Spacer()
                Text("Line1")
                    .lineLimit(1)
                Spacer()
            }
            HStack {
                Spacer()
                Text("Line2")
                    .lineLimit(1)
                Spacer()
            }
            HStack {
                Spacer()
                Text("Line3")
                    .lineLimit(1)
                Spacer()
            }
            HStack {
                Spacer()
                Text("Line4")
                    .lineLimit(1)
                Spacer()
            }
        })
        .hidden()
        .accessibilityHidden(true)
    }
}

extension View {
    @ViewBuilder
    func onLoad(perform action: (() -> Void)? = nil) -> some View {
        self
            .modifier(OnLoad(action: action))
    }
}
struct OnLoad: ViewModifier {
    @State
    private var loaded = false
    var action: (() -> Void)? = nil
    func body(content: Content) -> some View {
        content
            .onAppear(perform: {
                if loaded == false {
                    loaded = true
                    if let action {
                        action()
                    }
                }
            })
    }
}
