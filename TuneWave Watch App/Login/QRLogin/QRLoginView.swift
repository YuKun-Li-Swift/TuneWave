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
    @Environment(\.scenePhase)
    private var scenePhase
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
                        .accessibilityHidden(true)
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
                                .font(.headline.bold())
                                .foregroundStyle(.accent)
                                .multilineTextAlignment(.leading)
                            Spacer()
                        }
                        LoginQRView(qrImage: qrImage, vm: vm, refreshID: $refreshID)
                    } else {
                        ErrorView(errorText: "登录异常，"+DeveloperContactGenerator.generate())
                    }
                }
                .scenePadding(.horizontal)
            }
            .sheet(isPresented: $vm.showLargeQRSheet, content: {
                if let qrImage = vm.qr {
                    LoginQRView(qrImage: qrImage, vm: vm, refreshID: $refreshID)
                } else {
                    ScrollViewOrNot {
                        ErrorView(errorText: "登录异常，"+DeveloperContactGenerator.generate())
                    }
                }
            })
            .background(alignment: .center, content: {
                if scenePhase == .active {
                    Rectangle()
                        .fill(.clear)
                        .accessibilityHidden(true)
                        .frame(width: 1, height: 1, alignment: .center)
                    
                    .onReceive(timer, perform: { _ in
                        vm.checkScanStatus(mod: mod, modelContext: modelContext)
                    })
                } else {
                    //只在亮屏的时候轮询，熄屏幕必网络错误
                }
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

struct LoginQRView: View {
    var qrImage:UIImage
    var vm:YiQRLoginModel
    @Binding
    var refreshID:UUID
    @Environment(\.scenePhase)
    private var scenePhase
    var body: some View {
        Image(uiImage: qrImage)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .mask {
                switch vm.step3Status {
                case .waitingScan,.none:
                    Rectangle()
                case .waitingComfirm,.canceled,.error(_):
                    //显示错误的时候，使用圆角遮罩，匹配overlay的Material的形状
                    RoundedRectangle(cornerRadius: 16, style: .continuous)//这里的圆角更大一点，避免产生锯齿
                }
            }
            .overlay(alignment: .center) {
                switch vm.step3Status {
                case .none,.waitingScan:
                        Button {
                            vm.showLargeQRSheet.toggle()
                        } label: {
                            Color.touchZone
                        }
                        .buttonStyle(.plain)
                default:
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(Material.regular)
                        .overlay(alignment: .center) {
                            switch vm.step3Status {
                            case .waitingComfirm:
                                Text("请在手机上点击确认登录")
                                    .padding(.horizontal)
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
                                .padding(.horizontal)
                            case .error(let message):
                                if scenePhase != .active {
                                    Text("扫码登录过程中请保持Apple Watch屏幕点亮")//不然屏幕熄灭轮询就不做了
                                        .scenePadding(.horizontal)
                                        .transition(.blurReplace.animation(.smooth))
                                } else {
                                    Text(message)
                                        .padding(.horizontal)
                                        .transition(.blurReplace.animation(.smooth))
                                }
                            case .none,.waitingScan:
                                EmptyView()
                            }
                        }
                }
            }
            .padding([.top,.horizontal])//可以再向内收进去一点，二维码太大了手动滚到到位比较困难
        .id("QRImage")
    }
}

extension Color {
    public static var touchZone: Image {
        .init(uiImage: .init(color: .clear)!)
        .resizable()
    }
}

public extension UIImage {
    convenience init?(color: UIColor, size: CGSize = CGSize(width: 1, height: 1)) {
        let rect = CGRect(origin: .zero, size: size)
        UIGraphicsBeginImageContextWithOptions(rect.size, false, 0.0)
        color.setFill()
        UIRectFill(rect)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        guard let cgImage = image?.cgImage else { return nil }
        self.init(cgImage: cgImage)
    }
}
