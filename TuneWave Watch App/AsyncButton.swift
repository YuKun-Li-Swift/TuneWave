//
//  AsyncBUtton.swift
//  TuneWave Watch App
//
//  Created by Yukun Li on 2024/7/7.
//

import SwiftUI

struct AsyncButton: View {
    var buttonText:String
    @State
    private var loading = false
    var action:() async throws ->()
    var onError:(Error)->()
    var body: some View {
      Button(buttonText, action: {
          Task { @MainActor in
              withAnimation(.easeOut) {
                  loading = true
              }
              do {
                  try await action()
              } catch {
                  onError(error)
              }
              withAnimation(.smooth) {
                  loading = false
              }
          }
      })
      .allowsHitTesting(loading ? false : true)
      .brightness(loading ? -1 : 0)
      .overlay(alignment: .center) {
          if loading {
              ProgressView()
                  .transition(.scale(scale: 0.01, anchor: .center).combined(with: .opacity))
          }
      }
    }
}

