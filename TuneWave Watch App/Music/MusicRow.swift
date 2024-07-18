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
                                FixSizeImage(systemName: "photo.badge.arrow.down")
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .transition(.blurReplace.animation(.smooth))
                                    .clipShape(RoundedRectangle(cornerRadius: 16.7/3, style: .continuous))
                            case .failure(let error):
                                FixSizeImage(systemName: "wifi.exclamationmark")
                            }
                        }
                    } else {
                        FixSizeImage(systemName: "photo")
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

struct FixSizeImage: View {
    var systemName:String
    var body: some View {
        Rectangle()
            .fill(.clear)
            .aspectRatio(1, contentMode: .fit)
            .overlay(alignment: .center) {
                Image(systemName: systemName)
            }
            .transition(.blurReplace.animation(.smooth))
            .accessibilityRepresentation {
                Image(systemName: systemName)
            }
    }
}

struct FixSizeImageLarge: View {
    var systemName:String
    var body: some View {
        Rectangle()
            .fill(.clear)
            .aspectRatio(1, contentMode: .fit)
            .overlay(alignment: .center) {
                Image(systemName: systemName)
                    .imageScale(.large)
            }
            .transition(.blurReplace.animation(.smooth))            
            .accessibilityRepresentation {
                Image(systemName: systemName)
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

