//
//  LoginModel.swift
//  TuneWave Watch App
//
//  Created by Yukun Li on 2024/6/14.
//

import Foundation
import Alamofire
import SwiftyJSON
import SwiftUI



@Observable
class YiLoginModel {
    func loaginBy(phone:String,password:String) async throws {
        let route = "/login/cellphone"
        let fullURL = baseAPI + route
        let json = try await AF.request(fullURL,parameters: ["phone":phone,"password":password] as [String:String]).LSAsyncJSON()
        print("loaginBy\(json)")
    }
}



struct LoadingSkelton<V0:View,V1:View,V2:View>: View {
    var loadingView:()->(V0)
    var successView:()->(V1)
    var errorView:(Error)->(V2)
    var loadingAction:() async throws -> ()
    @State
    var stage:loadingStage = .loading
    var body: some View {
        VStack {
            switch self.stage {
            case .loading:
                loadingView()
            case .success:
                successView()
            case .error(let error):
                errorView(error)
            }
        }
        .onLoad {
            Task {
                do {
                    try await loadingAction()
                    Task { @MainActor in
                        withAnimation(.smooth) {
                            self.stage = .success
                        }
                    }
                } catch {
                    Task { @MainActor in
                        withAnimation(.smooth) {
                            self.stage = .error(error)
                        }
                    }
                }
            }
        }
    }
}

struct APIErrorDisplay: View {
    var remoteControlTag:String
    var error:Error
    @State
    var showSheet = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                Text("出错了")
                    .font(.headline)
                Button {
                    self.showSheet = true
                } label: {
                    Text("请点此联系开发者")
                }
                Divider()
                Text("错误报告：")
                Text(error.localizedDescription)
                    .font(.footnote)
            }
        }
        .sheet(isPresented: $showSheet) {
            qrSheet()
        }
    }
    @ViewBuilder
    func qrSheet() -> some View {
        ScrollView {
            Image(.contactQR)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .navigationTitle("手机扫码联系开发者")
        }
    }
}



extension LoadingSkelton {
    enum loadingStage:Equatable {
        static func == (lhs: LoadingSkelton<V0, V1, V2>.loadingStage, rhs: LoadingSkelton<V0, V1, V2>.loadingStage) -> Bool {
            if lhs == .loading && rhs == .loading {
                return true
            } else if lhs == .success && rhs == .success {
                return true
            } else {
                switch lhs {
                case .loading:
                    break
                case .success:
                    break
                case .error(let error1):
                    switch rhs {
                    case .loading:
                        break
                    case .success:
                        break
                    case .error(let error2):
                        if error1.localizedDescription == error2.localizedDescription {
                            return true
                        }
                    }
                }
                return false
            }
        }
        
        case loading
        case success
        case error(Error)
    }
}


extension Alamofire.DataRequest {
    enum asyncResponseError:Error {
        case unknowError
    }
    func LSAsyncJSON() async throws -> JSON {
        try await withUnsafeThrowingContinuation { continuation in
            self.response { response in
                if let data = response.data {
                    let json = JSON(data)
                    continuation.resume(returning: json)
                } else {
                    if let error = response.error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(throwing: asyncResponseError.unknowError)
                    }
                }
            }
        }
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
    var action: (() -> Void)? = nil
    func body(content: Content) -> some View {
        content
            .onAppear(perform: action)
    }
}

