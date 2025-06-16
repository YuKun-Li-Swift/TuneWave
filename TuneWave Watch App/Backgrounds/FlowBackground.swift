//
//  MeshModel.swift
//  PlayWithMesh
//
//  Created by 凌嘉徽 on 2025/3/22.
//


//
//  ContentView.swift
//  PlayWithMeshGradient Watch App
//
//  Created by 凌嘉徽 on 2024/11/19.
//

import SwiftUI
import os

@Observable
fileprivate
class MeshModel {
    struct MeshPositionPack {
        var positions:[SIMD2<Float>]
    }
    var phase = 0.0
    var meshData:MeshPositionPack
    init() {
        meshData = .init(positions: MeshModel.initAnimatedPositions(for: 0))
    }
    func update() {
        meshData = .init(positions: animatedPositions(phase: phase))
    }
    private
    var positions: [SIMD2<Float>] = [
        SIMD2<Float>(0.0, 0.0),
        SIMD2<Float>(0.5, 0.0),
        SIMD2<Float>(1.0, 0.0),
        SIMD2<Float>(0.0, 0.5),
        SIMD2<Float>(0.45, 0.55),
        SIMD2<Float>(1.0, 0.5),
        SIMD2<Float>(0.0, 1.0),
        SIMD2<Float>(0.5, 1.0),
        SIMD2<Float>(1.0, 1.0)
    ]
    private
    func animatedPositions(phase:Double) -> [SIMD2<Float>] {
        var animatedPositions = positions
        
        animatedPositions[1].x = 0.5 + 0.4 * Float(cos(phase))
        animatedPositions[3].y = 0.5 + 0.3 * Float(cos(phase * 1.1))
        animatedPositions[4].y = 0.5 - 0.4 * Float(cos(phase * 0.9))
        animatedPositions[5].y = 0.5 - 0.2 * Float(cos(phase * 0.9))
        animatedPositions[7].x = 0.5 - 0.4 * Float(cos(phase * 1.2))
        
        return animatedPositions
    }
    private
    static
    func initAnimatedPositions(for phase: Double) -> [SIMD2<Float>] {
        let positions: [SIMD2<Float>] = [
            SIMD2<Float>(0.0, 0.0),
            SIMD2<Float>(0.5, 0.0),
            SIMD2<Float>(1.0, 0.0),
            SIMD2<Float>(0.0, 0.5),
            SIMD2<Float>(0.45, 0.55),
            SIMD2<Float>(1.0, 0.5),
            SIMD2<Float>(0.0, 1.0),
            SIMD2<Float>(0.5, 1.0),
            SIMD2<Float>(1.0, 1.0)
        ]
        var animatedPositions = positions
        
        animatedPositions[1].x = 0.5 + 0.4 * Float(cos(phase))
        animatedPositions[3].y = 0.5 + 0.3 * Float(cos(phase * 1.1))
        animatedPositions[4].y = 0.5 - 0.4 * Float(cos(phase * 0.9))
        animatedPositions[5].y = 0.5 - 0.2 * Float(cos(phase * 0.9))
        animatedPositions[7].x = 0.5 - 0.4 * Float(cos(phase * 1.2))
        
        return animatedPositions
    }
}

@available(watchOS 11.0, *)
struct FlowBackground: View {
    var sourceImage:UIImage
    @Binding
    var playing:Bool
    @State
    private var startDate = Date.now
    @Environment(\.scenePhase)
    private var scenePhase
    @Environment(\.isLuminanceReduced)
    private var isLuminanceReduced
    private var shouldAnimate:Bool {
        // App在前台并且没有放下手腕
        if scenePhase == .active && !isLuminanceReduced {
            return true
        } else {
            return false
        }
    }
    @State
    private
    var colors: [Color]? = nil
    @State
    private var meshModel = MeshModel()
    @State
    private var updateMeshPositionTimer = Timer.publish(every: 1/60, tolerance: 1/30/*允许轻微帧生成时间不稳定*/, on: .main, in: .default).autoconnect()
    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            if let colors {
                VStack {
                    VStack {
                        MeshGradient(
                            width: 3,
                            height: 3,
                            locations: .points(meshModel.meshData.positions),
                            colors: .colors(colors),
                            background: Color(red: 0.000, green: 0.000, blue: 0.000),
                            smoothsColors: true
                        )
                    }
                    .background {
                        if shouldAnimate && playing {
                            EmptyView()
                                .onReceive(updateMeshPositionTimer) { date in
                                    // 如果不更新就不加phase，做到真“从哪里暂停就从哪里继续”
                                    let speedRatio = 1.23
                                    meshModel.phase += (1/60) * speedRatio
                                    meshModel.update()
                                }
                        }
                    }
                }
                .ignoresSafeArea()
                // 因为ignoresSafeArea了，transition就只能用opacity了，不然安全区会丢失transition动画，硬切。
                .transition(.opacity.animation(.smooth))
            } else {
                ProgressView()
                    .transition(.blurReplace.animation(.smooth))
                    .task { @MainActor in
                        colors = await ImagePaletter.getColors(sourceImage: sourceImage)
                    }
            }
        }
        //切换图片的时候，重新加载颜色
        .onChange(of: sourceImage, initial: false) { oldValue, newValue in
            colors = nil
        }
        .animation(.smooth, value: colors)
    }
}

actor ImagePaletter {
    static
    func getColors(sourceImage:UIImage) async -> [Color] {
        let res = ColorThief.getPalette(from: sourceImage, colorCount: 9)!
        return res.map({ mmcq in
            Color(red: Double(mmcq.r)/255, green: Double(mmcq.g)/255, blue: Double(mmcq.b)/255)
        })
    }
}
