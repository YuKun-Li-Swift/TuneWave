//
//  LoginPage.swift
//  TuneWave Watch App
//
//  Created by Yukun Li on 2024/6/14.
//

import SwiftUI

struct LoginPage: View {
    @State
    var mod = YiLoginModel()
    var body: some View {
        LoadingSkelton {
            ProgressView()
        } successView: {
            Text("加载完成")
        } errorView: { error in
            APIErrorDisplay(remoteControlTag: "loginPage", error: error)
        } loadingAction: {
            try await mod.loaginBy(phone: "13282500836", password: "Ljh,8123")
        }

    }
}



#Preview {
    LoginPage()
}
