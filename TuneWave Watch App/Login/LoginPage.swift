//
//  LoginPage.swift
//  TuneWave Watch App
//
//  Created by Yukun Li on 2024/6/14.
//

import SwiftUI
import SwiftData

@MainActor
struct LoginPage: View {
    @Environment(YiUserContainer.self)
    var userContainer:YiUserContainer?
    @State
    var showLogoutSuccessAlert = false
    var body: some View {
        VStack {
            if let userContainer {
                UserInfoView(showLogoutSuccessAlert:{
                    showLogoutSuccessAlert = true
                },userContainer:userContainer)
            } else {
                LoginView()
            }
        }
        .alert("已退出登录", isPresented: $showLogoutSuccessAlert, actions: {})
        
    }
}

@MainActor
struct LoginView: View {
    @State
    var mod = YiLoginModel()
    @Environment(\.modelContext)
    var modelContext
    enum LoginMethod {
        case password
        case verificationCode
    }
    @State
    private var selectedLoginMethod = LoginMethod.verificationCode
    @State
    private var phonePasswordShip:PhonePasswordLogin? = nil
    @State
    var showTipView = true
    var body: some View {
        VStack(content: {
            if showTipView {
                LoginTipView(continue: $showTipView)
            } else {
                ScrollView {
                    VStack {
                       
                        switch selectedLoginMethod {
                        case .password:
                            PhonePasswordLoginView(mod: mod)
                        case .verificationCode:
                            PhoneVerificationCodeLoginView(mod: mod)
                        }
                        
                    }
                    .toolbar {
                        ToolbarItemGroup(placement: .automatic) {
                            Picker("选择登录方式", selection: $selectedLoginMethod, content: {
                                Text("手机号+密码")
                                    .tag(LoginMethod.password)
                                Text("短信验证码")
                                    .tag(LoginMethod.verificationCode)
                            })
                            .pickerStyle(.navigationLink)
                            .tint(.blue)
                        }
                    }
                    
                }
            }
        })
        .navigationDestination(item: $phonePasswordShip, destination: { ship in
            LoginPageDemo()
        })
        .navigationTitle("登录账号")
    }
}

struct LoginTipView: View {
    @Binding
    var `continue`:Bool
    var body: some View {
        Text("您正在登录的是网易云音乐账号")
        Button("继续") {
            withAnimation(.easeOut) {
                `continue` = true
            }
        }
        .buttonStyle(.borderedProminent)
    }
}



struct PhonePasswordLogin:Identifiable,Hashable {
    var id = UUID()
    var phone:String
    var password:String
}

struct PhonePasswordLoginView: View {
    @State
    var mod:YiLoginModel
    @Environment(\.modelContext)
    var modelContext
    @AppStorage("PhoneNumberInPhonePasswordLoginView")
    var phoneNumber = ""    
    @AppStorage("CtCodeInPhonePasswordLoginView")
    var ctCode = "86"
    @State//这可不能存AppStorage里了，不然太危险了
    var password = ""
    
    @State
    var loginError:String? = nil
    @State
    var showloginErrorSheet = false
    var body: some View {
        VStack(content: {
            PhoneNumberEnter(ctCode: $ctCode, text: $phoneNumber)
            SecureField("请输入密码", text: $password)
            if !phoneNumber.isEmpty && !password.isEmpty {
                AsyncButton(buttonText: "确认登录", action: {
                    loginError = nil
                    showloginErrorSheet = false
                    try await mod.loaginBy(phone: phoneNumber, countrycode: ctCode, password:password, modelContext: modelContext)
                }, onError: { error in
                    loginError = error.localizedDescription
                    showloginErrorSheet = true
                })
                .buttonStyle(.borderedProminent)
                .transition(.blurReplace)
            } else {
                Rectangle()
                    .frame(height: 30)
                    .hidden()
            }
        })
        .animation(.smooth, value: password)
            .alert(loginError ?? "未知错误", isPresented: $showloginErrorSheet, actions: {
                
            })
    }
}

struct PhoneNumberEnter: View {
    @Binding
    var ctCode:String
    @Binding
    var text:String
    var body: some View {
        VStack(alignment: .leading) {
            NavigationLink {
                    ScrollViewOrNot {
                        VStack {
                            Text("如果您的手机号不是中国大陆手机号，请在下方输入手机号国家区号")
                            TextField("手机号国家区号", text: $ctCode)
                        }
                    }
            } label: {
                if ctCode == "86" {
                    Text("🇨🇳中国大陆手机号")
                } else {
                    Text("国家区号：+"+ctCode)
                }
            }
            TextField("请输入手机号", text: $text)
        }
    }
}



@MainActor
struct PhoneVerificationCodeLoginView: View {
    @State
    var mod:YiLoginModel
    @Environment(\.modelContext)
    var modelContext
    @AppStorage("PhoneNumberInPhoneVerificationCodeLoginView")
    var phoneNumber = ""
    @AppStorage("CtCodeInPhoneVerificationCodeLoginView")
    var ctCode = "86"
    @State
    var verificationCodeSendError:String? = nil
    @State
    var showVerificationCodeSendErrorSheet = false
    @State
    var verificationCodeSendSuccessfully = false
    @State
    var verificationCode = ""
    @State
    var loginError:String? = nil
    @State
    var showloginErrorSheet = false
    var body: some View {
        VStack(alignment: .leading) {
            PhoneNumberEnter(ctCode: $ctCode, text: $phoneNumber)
            if !phoneNumber.isEmpty {
                VerificationCodeSendButton(showVerificationCodeSendErrorSheet: $showVerificationCodeSendErrorSheet, verificationCodeSendError: $verificationCodeSendError, mod: mod, verificationCodeSendSuccessfully: $verificationCodeSendSuccessfully, phoneNumber: $phoneNumber, ctCode: $ctCode)
                    .buttonStyle(.bordered)
                    .tint(verificationCodeSendSuccessfully ? nil : .accent)
                    .transition(.blurReplace)
            } else {
                Rectangle()
                    .frame(height: 30)
                    .hidden()
            }
            if verificationCodeSendSuccessfully {
                TextField("请输入短信验证码", text: $verificationCode)
                if !verificationCode.isEmpty {
                    AsyncButton(buttonText: "确认登录", action: {
                        loginError = nil
                        showloginErrorSheet = false
                        try await mod.loaginBy(phone: phoneNumber, countrycode: ctCode, captcha: verificationCode, modelContext: modelContext)
                    }, onError: { error in
                        loginError = error.localizedDescription
                        showloginErrorSheet = true
                    }) 
                    .buttonStyle(.borderedProminent)
                    .transition(.blurReplace)
                } else {
                    Rectangle()
                        .frame(height: 30)
                        .hidden()
                }
            }
        }
        .alert(verificationCodeSendError ?? "未知错误", isPresented: $showVerificationCodeSendErrorSheet, actions: {
            
        })   
        .alert(loginError ?? "未知错误", isPresented: $showloginErrorSheet, actions: {
            
        })
        .animation(.smooth, value: phoneNumber)
        .animation(.smooth, value: ctCode)
        .animation(.smooth, value: verificationCodeSendSuccessfully)
        .animation(.smooth, value: verificationCode)
    }
    
}

struct VerificationCodeSendButton: View {
    @Binding
    var showVerificationCodeSendErrorSheet:Bool
    @Binding
    var verificationCodeSendError:String?
    var mod:YiLoginModel
    @Binding
    var verificationCodeSendSuccessfully:Bool
    @Binding
    var phoneNumber:String
    @Binding
    var ctCode:String
    @State
    var timer = Timer.publish(every: 1, on: .main, in: .default).autoconnect()
    @State
    var count = 60
    @State
    var startToCount = false
    @State
    var buttonLabel = "发送短信验证码"
    var body: some View {
        AsyncButton(buttonText: buttonLabel) {
            showVerificationCodeSendErrorSheet = false
            verificationCodeSendError = nil
            try await mod.sendVerificationCode(phoneNumber: phoneNumber,ctcode: ctCode)
            verificationCodeSendSuccessfully = true
            count = 60
            startToCount = true
        } onError: { error in
            self.verificationCodeSendError = error.localizedDescription
            self.showVerificationCodeSendErrorSheet = true
        }
        .contentTransition(.numericText())
        .onReceive(timer) { _ in
            if startToCount {
                count -= 1
            }
        }
        .onChange(of: startToCount, initial: true) { oldValue, newValue in
            decidedLabel(startToCount: startToCount, count: count)
        }
        .onChange(of: count, initial: true) { oldValue, newValue in
            decidedLabel(startToCount: startToCount, count: count)
        }
    }
    func decidedLabel(startToCount:Bool,count:Int) {
        let result:String = {
            if startToCount && count > 0 {
                "再次发送验证码（\(count)秒）"
            } else {
                "发送短信验证码"
            }
        }()
        self.buttonLabel = result
    }
}



@MainActor
struct LoginPageDemo: View {
    @State
    var mod = YiLoginModel()
    @Environment(\.modelContext)
    var modelContext
    var body: some View {
        LoadingSkelton {
            ProgressView()
        } successView: {
            Text("加载完成")
        } errorView: { error in
            APIErrorDisplay(remoteControlTag: "loginPage", error: error)
        } loadingAction: {
            try await mod.loaginBy(phone: "yourPhoneNumber", countrycode: "86", password: "yourPassword", modelContext: modelContext)
        }
    }
}



#Preview {
    LoginPageDemo()
}
