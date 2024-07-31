//
//  DisclaimerView.swift
//  TuneWave Watch App
//
//  Created by Yukun Li on 2024/7/17.
//

import SwiftUI

struct DisclaimerView: View {
    @State
    private var showDetail = false
    var body: some View {
        Button(action: {
            showDetail = true
        }, label: {
            Label("免责声明", systemImage: "shield")
        })
            .navigationDestination(isPresented: $showDetail, destination: {
                ScrollView {
                    VStack(alignment: .leading, content: {
                        Text({
                            enum DisclaimerViewError:Error,LocalizedError {
                            case noFile
                                var errorDescription: String? {
                                    switch self {
                                    case .noFile:
                                        "请补充免责声明文件，避免法律风险"
                                    }
                                }
                            }
                            do {
                                if let url = Bundle.main.url(forResource: "DisclaimerContent", withExtension: "md") {
                                    return try String(contentsOf: url)
                                } else {
                                    throw DisclaimerViewError.noFile
                                }
                            } catch {
                                #if DEBUG
                                fatalError("请补充免责声明文件，避免法律风险")
                                #endif
                                return error.localizedDescription
                            }
                        }())
                    })
                    .scenePadding(.horizontal)
                    .navigationTitle("免责声明")
                    .navigationBarTitleDisplayMode(.large)
                }
            })
    }
  
}

#Preview {
    DisclaimerView()
}
