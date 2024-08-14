//
//  QRLoginView.swift
//  TuneWave Watch App
//
//  Created by Yukun Li on 2024/8/8.
//

import SwiftUI

//部分小伙伴用验证码或密码登录，会提示有风险不让登录（可能是开启了某种保护机制？可能是某个请求头或者Cookie没传？不知道）。
//做个二维码登录应该可以正常登录了。

struct QRLoginViewPack: View {
    var scrollProxy:ScrollViewProxy
    @State
    private var refreshID = UUID()
    var body: some View {
        QRLoginView(refreshID:$refreshID,scrollProxy:scrollProxy)
            .id(refreshID)
    }
}


@MainActor
struct QRLoginView: View {
    @Binding
    var refreshID:UUID
    var scrollProxy:ScrollViewProxy
    @State
    var vm = YiQRLoginModel()
    @State
    private var size:CGSize?
    @State
    private var timer = Timer.publish(every: 1, on: .main, in: .default).autoconnect()
    @State
    private var mod = YiLoginModel()
    @Environment(\.modelContext)
    var modelContext
    var body: some View {
        LoadingSkelton {
            ProgressView()
        } successView: {
            ZStack {
                //测量可用空间的横向宽度（不算padding），作为二维码图片的尺寸
                GeometryReader { proxy in
                    Text("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
                        .lineLimit(1)
                        .minimumScaleFactor(0.01)
                        .hidden()
                        .onAppear {
                            self.size = proxy.size
                        }
                }
                .padding(.horizontal)
                .accessibilityHidden(true)
                VStack(spacing:0) {
                    if let qrImage = vm.qr {
                        HStack {
                            Text("请使用网易云音乐app扫码")
                                .font(.headline)
                                .foregroundStyle(.accent)
                                .multilineTextAlignment(.leading)
                            Spacer()
                        }
                        Image(uiImage: qrImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: size?.width, height: size?.width, alignment: .center)
                            .padding(.top, 13)//13刚好可以滚动到屏幕中心
                            .id("QRImage")
                            .mask {
                                switch vm.step3Status {
                                case .waitingScan,.none:
                                    Rectangle()
                                case .waitingComfirm,.canceled,.unknow(_):
                                    //显示错误的时候，使用圆角遮罩，匹配overlay的Material的形状
                                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                                }
                            }
                            .overlay(alignment: .center) {
                                switch vm.step3Status {
                                case .none,.waitingScan:
                                    EmptyView()
                                default:
                                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                                        .fill(Material.regular)
                                        .overlay(alignment: .center) {
                                            switch vm.step3Status {
                                            case .waitingComfirm:
                                                Text("请在手机上点击确认登录")
                                            case .canceled:
                                                VStack {
                                                    Text("该二维码已失效")
                                                    Button("刷新二维码") {
                                                        withAnimation(.easeOut) {
                                                            refreshID = UUID()
                                                        }
                                                    }
                                                    .buttonStyle(.borderedProminent)
                                                }
                                            case .unknow(let message):
                                                Text(message)
                                            case .none,.waitingScan:
                                                EmptyView()
                                            }
                                        }
                                    
                                }
                             
                            }
                    } else {
                        ErrorView(errorText: "登录异常，"+DeveloperContactGenerator.generate())
                    }
                }
                .scenePadding(.horizontal)
            }
            .onAppear {
                Task {
                    try? await Task.sleep(nanoseconds: 1000000000)//1s，不要在View刚出现就触发滚动，会没反应。1秒让用户看清提示文本
                    withAnimation(.easeOut) {
                        scrollProxy.scrollTo("QRImage", anchor: .center)
                    }
                }
            }
            .onReceive(timer, perform: { _ in
                vm.checkScanStatus(mod: mod, modelContext: modelContext)
            })
            .animation(.smooth, value: vm.step3Status)
        } errorView: { error in
            APIErrorDisplay(remoteControlTag: "qrLogin", error: error)
        } loadingAction: {
            vm = YiQRLoginModel()//reset，避免页面关闭了但实际上没有销毁vm
            try await vm.step1()
            try await vm.step2()
        }
    }
}

