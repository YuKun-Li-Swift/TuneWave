//
//  MusicROw.swift
//  TuneWave Watch App
//
//  Created by Yukun Li on 2024/7/9.
//

import SwiftUI
import SDWebImageSwiftUI

struct MusicRowSingleLine: View {
    var tapAction:()->()
    var imageURL:URL?
    var name:String
    var body: some View {
        Button {
            tapAction()
        } label: {
            HStack(alignment: .center, spacing: 13) {
           
                VStack {
                    if let imageURL {
                        WebImage(url: imageURL.lowRes(xy2x: 80), transaction: .init(animation: .smooth)) { phase in
                            switch phase {
                            case .empty:
                                Rectangle()
                                    .fill(.clear)
                                    .aspectRatio(1, contentMode: .fit)
                                    .overlay(alignment: .center) {
                                        Image(systemName: "photo.badge.arrow.down")
                                    }
                                .transition(.blurReplace.animation(.smooth))
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .transition(.blurReplace.animation(.smooth))
                                    .clipShape(RoundedRectangle(cornerRadius: 16.7/3, style: .continuous))
                            case .failure(let error):
                                Image(systemName: "wifi.exclamationmark")
                                    .transition(.blurReplace.animation(.smooth))
                            }
                        }
                    } else {
                        Image(systemName: "photo")
                            .transition(.blurReplace.animation(.smooth))
                    }
                
                }
                .frame(height: 40)
                
                Text(name)
                    .padding(.vertical, 16.7/3)
                Spacer()
            }
        }

    }
}


struct MusicRowGrid: View {
    var body: some View {
        VStack(alignment: .center, spacing: 16.7/2) {
            Rectangle()
                .aspectRatio(1, contentMode: .fit)
                .overlay(alignment: .center) {
                    Image(uiImage: .init())
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                }
            ViewThatFits {
                ScrollView(.horizontal) {
                    Text("我是歌名")
                        .font(.headline)
                }
                Text("我是歌名")
                    .font(.headline)
            }
         
        }
    }
}

