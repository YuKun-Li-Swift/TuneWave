//
//  ContentView.swift
//  PlayWithMeshGradient Watch App
//
//  Created by 凌嘉徽 on 2024/11/19.
//

import SwiftUI


@available(watchOS 11.0, *)
struct FlowBackground: View {
    var sourceImage:UIImage
    @State private var positions: [SIMD2<Float>] = [
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

    @State
    private var colors: [Color]? = nil
//    [
//        Color(red: 0.922, green: 0.000, blue: 0.000),
//        Color(red: 1.000, green: 0.535, blue: 0.000),
//        Color(red: 0.924, green: 0.915, blue: 0.000),
//        Color(red: 1.000, green: 0.000, blue: 0.465),
//        Color(red: 0.000, green: 0.749, blue: 1.000),
//        Color(red: 0.000, green: 1.000, blue: 0.603),
//        Color(red: 0.576, green: 0.000, blue: 1.000),
//        Color(red: 1.000, green: 0.000, blue: 0.733),
//        Color(red: 0.000, green: 0.980, blue: 0.864)
//    ]
    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            if let colors {
                TimelineView(.animation) { phase in
                  MeshGradient(
                    width: 3,
                    height: 3,
                    locations: .points(animatedPositions(for: phase.date)),
                    colors: .colors(colors),
                    background: Color(red: 0.000, green: 0.000, blue: 0.000),
                    smoothsColors: true
                  )
                }
                .transition(.opacity.animation(.smooth))
                .ignoresSafeArea()
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
    }

    private
    func animatedPositions(for date: Date) -> [SIMD2<Float>] {
      let phase = CGFloat(date.timeIntervalSince1970)
      var animatedPositions = positions

      animatedPositions[1].x = 0.5 + 0.4 * Float(cos(phase))
      animatedPositions[3].y = 0.5 + 0.3 * Float(cos(phase * 1.1))
      animatedPositions[4].y = 0.5 - 0.4 * Float(cos(phase * 0.9))
      animatedPositions[5].y = 0.5 - 0.2 * Float(cos(phase * 0.9))
      animatedPositions[7].x = 0.5 - 0.4 * Float(cos(phase * 1.2))

      return animatedPositions
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
