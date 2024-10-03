//
//  MusicROw.swift
//  TuneWave Watch App
//
//  Created by Yukun Li on 2024/7/9.
//

import SwiftUI
import SDWebImageSwiftUI


struct MusicRowSingleLine<V:View>: View {
    var tapAction:() async throws ->()
    @Binding
    var imageURL:URL?
    var name:String
    @Binding
    var hightlight:Bool
    var attatchView:()->(V)
    init(tapAction: @escaping () async throws -> Void, imageURL: Binding<URL?>, name: String, hightlight: Binding<Bool>,attatchView:@escaping ()->(V) = { EmptyView() }) {
        self.tapAction = tapAction
        self._imageURL = imageURL
        self.name = name
        self._hightlight = hightlight
        self.attatchView = attatchView
    }
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
                    guard !Task.isCancelled else { return }
                    loading = true
                    guard !Task.isCancelled else { return }
                    errorText = nil
                    guard !Task.isCancelled else { return }
                    do {
                        guard !Task.isCancelled else { return }
                        try await tapAction()
                        guard !Task.isCancelled else { return }
                    } catch {
                        guard !Task.isCancelled else { return }
                        errorText = error.localizedDescription
                    }
                    guard !Task.isCancelled else { return }
                    loading = false
                }
            }
        } label: {
            VStack(spacing: 0, content: {
                HStack(alignment: .center, spacing: 13) {
                    VStack {
                        if let imageURL {
                            ImageViewForMusicRowSingleLine(imageURL: imageURL)
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
                attatchView()
            })
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


struct ImageViewForMusicRowSingleLine: View {
    var imageURL:URL
    var body: some View {
        if imageURL.isFileURL {
            InlineCoverLocalImageView(imageURL: imageURL)
        } else {
            WebImage(url: imageURL.lowRes(xy2x: 80)) { phase in
                switch phase {
                case .empty:
                    FixSizeImage(systemName: "photo.badge.arrow.down")
                        .transition(.blurReplace.animation(.smooth))
                case .success(let image):
                    InlineCoverImageView(image: image)
                        .transition(.blurReplace.animation(.smooth))
                case .failure( _):
                    FixSizeImage(systemName: "wifi.exclamationmark")
                        .transition(.blurReplace.animation(.smooth))
                }
            }
        }
    }
}

struct InlineCoverLocalImageView: View {
    var imageURL:URL
    @State
    private var uiimage:UIImage? = nil
    @State
    private var loadLocalImageError:Error? = nil
    @State
    private var asyncImageLoader = LocalImageLoader()
    var body: some View {
        
            Group {
                if let uiimage {
                    InlineCoverImageView(image: .init(uiImage: uiimage))
                        .transition(.blurReplace.animation(.smooth))
                } else if let loadLocalImageError {
                    FixSizeImage(systemName: "photo")
                        .id("LoadingOrError")//标识符，避免重新渲染
                } else {
                    FixSizeImage(systemName: "photo")
                        .id("LoadingOrError")//标识符，避免重新渲染
                }
            }
            .task {
                do {
                    loadLocalImageError = nil
                    self.uiimage = try await asyncImageLoader.loadLocalImage(imageURL:imageURL)
                } catch {
                    loadLocalImageError = error
                }
            }
        
    }
}

actor LocalImageLoader {
    func loadLocalImage(imageURL:URL) throws -> UIImage {
        let data = try Data(contentsOf: imageURL)
        guard !Task.isCancelled else { throw LoadLocalImageError.canceled }
        let screenSize = WKInterfaceDevice.current().screenBounds
        let thumbnailImageSize = max(screenSize.width,screenSize.height)
        guard let cgImage:CGImage = myCreateThumbnailImageFromData(data: data, imageSize: Int(thumbnailImageSize)) else {
            throw LoadLocalImageError.failedToInitUIImage
        }
        let uiImage:UIImage = UIImage(cgImage: cgImage)
        guard !Task.isCancelled else { throw LoadLocalImageError.canceled }
        return uiImage
    }
    func myCreateThumbnailImageFromData(data: Data, imageSize: Int) -> CGImage? {
        var myThumbnailImage: CGImage? = nil
        var myImageSource: CGImageSource?
        var myOptions: [CFString: Any]?
        let myKeys: [CFString] = [kCGImageSourceCreateThumbnailWithTransform as CFString, kCGImageSourceCreateThumbnailFromImageIfAbsent as CFString, kCGImageSourceThumbnailMaxPixelSize as CFString]
        let myValues: [Any] = [kCFBooleanTrue, kCFBooleanTrue, imageSize as Any]
        
        // Create an image source from Data; no options.
        myImageSource = CGImageSourceCreateWithData(data as CFData, nil)
        
        // Make sure the image source exists before continuing.
        guard myImageSource != nil else {
            print("Image source is NULL.")
            return nil
        }
        
        // Set up the thumbnail options.
        myOptions = Dictionary(uniqueKeysWithValues: zip(myKeys, myValues))
        
        // Create the thumbnail image using the specified options.
        myThumbnailImage = CGImageSourceCreateThumbnailAtIndex(myImageSource!, 0, myOptions as CFDictionary?)
        
        // Release the options dictionary and the image source when you no longer need them.
        // (In Swift, this is handled automatically by the memory management system.)
        
        // Make sure the thumbnail image exists before continuing.
        guard myThumbnailImage != nil else {
            print("Thumbnail image not created from image source.")
            return nil
        }
        
        return myThumbnailImage
    }
    private enum LoadLocalImageError:Error,LocalizedError {
        case failedToInitUIImage
        case canceled
        var errorDescription: String? {
            switch self {
            case .failedToInitUIImage:
                "无法加载封面图"
            case .canceled:
                "加载已取消"
            }
        }
    }
}

struct InlineCoverImageView: View {
    var image:Image
    var body: some View {
        
            image
                .resizable()
                .aspectRatio(contentMode: .fit)
                .transition(.blurReplace.animation(.smooth))
                .clipShape(RoundedRectangle(cornerRadius: 16.7/3, style: .continuous))
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

