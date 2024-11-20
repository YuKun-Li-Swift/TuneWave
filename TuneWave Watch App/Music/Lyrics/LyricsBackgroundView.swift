//
//  LyricsBackgroundView.swift
//  TuneWave
//
//  Created by Yukun Li on 2024/11/19.
//

import SwiftUI

@available(watchOS 11.0, *)
struct LyricsBackgroundView: View {
    let currentMusic:YiMusic
    @State
    private var coverImage:UIImage? = nil
    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            if let coverImage {
                FlowBackground(sourceImage: coverImage)
                    .transition(.opacity.animation(.smooth))
            } else {
                ProgressView()
                    .transition(.blurReplace.animation(.smooth))
                    .task { @MainActor in
                        do {
                            coverImage = try ImageLoader.dataToUIImage(data: currentMusic.albumImg)
                        } catch {
                            
                            print("封面图加载失败")
                            print(error.localizedDescription)
                        }
                    }
            }
        }
        //切换音乐的时候，重新加载图片
        .onChange(of: currentMusic, initial: false) { oldValue, newValue in
            coverImage = nil
        }
    }
}

fileprivate
actor ImageLoader {
    enum LoadImageError:Error,LocalizedError {
        case notAUIImage
        var errorDescription: String? {
            switch self {
            case .notAUIImage:
                "加载图片失败，数据格式不满足要求"
            }
        }
    }
    static
    func dataToUIImage(data:Data) throws -> UIImage {
        guard let uiImage :UIImage = UIImage(data: data) else {
            throw LoadImageError.notAUIImage
        }
        return uiImage
    }
}
