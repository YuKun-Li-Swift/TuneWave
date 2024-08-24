//
//  AlamofireCacheExtension.swift
//  TuneWave Watch App
//
//  Created by Yukun Li on 2024/7/11.
//

import Foundation
import Alamofire

//AlamofireTuneWave
let AFTW = {
    //Apple Watch用户经常会在加载到一半时候放下手腕
    //此时Apple Watch会断网，除非使用了.background的URLSession
    //为了避免用户一抬手腕就显示“网络错误”，我们使用waitsForConnectivity来允许请求等待，直到用户下次抬起手腕为止
    //虽然使用.background的URLSession可以在后台联网，但是也会带来后台联网额外的耗电（保持网络连接+耗电），我们不希望悦音音乐显得很不节能
    //当然最大的问题是Alamofire不支持.background的URLSession，我们不可能放弃Alamofire，这会徒增代码的复杂度
    //所以我们选择让请求在用户放下手腕（断网）的过程中保持等待，解决用户一放下手腕再抬起、就显示网络错误的问题，这样已经巨大改进用户体验了；而并不去追求真正的要在用户垂下手腕还硬要继续联网，把请求做完。
    let configuration:URLSessionConfiguration = .default
    configuration.waitsForConnectivity = true
    configuration.timeoutIntervalForResource = 60*60//1hour
    return Session(configuration: configuration)
}()
