//
//  MusicROw.swift
//  TuneWave Watch App
//
//  Created by Yukun Li on 2024/7/9.
//

import SwiftUI
import SDWebImageSwiftUI

struct MusicRowSingleLine: View {
    var tapAction:() async throws ->()
    var imageURL:URL?
    var name:String
    var hightlight:Bool = false
    @State
    private var loading = false
    @State
    private var errorText:String? = nil
    @State
    private var loadingTask:Task<Void,Never>?
    var body: some View {
        Button {
            //如果上一次点击还没加载完，不允许下一次
            if !loading {
                loadingTask = Task {
                    loading = true
                    errorText = nil
                    do {
                        try await tapAction()
                    } catch {
                        //离屏了就不要弹出错误了
                        if !Task.isCancelled {
                            errorText = error.localizedDescription
                        }
                    }
                    loading = false
                }
            }
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
                            case .failure( _):
                                FixSizeImage(systemName: "wifi.exclamationmark")
                            }
                        }
                    } else {
                        FixSizeImage(systemName: "photo")
                    }
                
                }
                .frame(height: 40)
                if hightlight {
                    
                    Text(name)
                        .shadow(radius: 5, x: 3, y: 3)
                        .padding(.vertical, 16.7/3)
                } else {
                    
                    Text(name)
                        .padding(.vertical, 16.7/3)
                }
                Spacer()
            }
            .opacity(loading ? 0 : 1)
            .overlay(alignment: .center) {
                if loading {
                    ProgressView()
                }
            }
            .animation(.smooth, value: loading)
        }
        .onDisappear {
            //离屏了就不要加载了
            loading = false
            errorText = nil
            loadingTask?.cancel()
        }
        .alert(errorText ?? "未知错误", isPresented: Binding<Bool>(get:{
            errorText != nil
        },set: { show in
            if show {
                //不需要操作，保持打开
            } else {
                //关闭
                self.errorText = nil
            }
        }), actions: {})
        .listRowBackground({
            if hightlight {
                return RoundedRectangle(cornerRadius: 13, style: .continuous) .fill(Color.accentColor.gradient)
            } else {
                return nil
            }
        }())
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

