//
//  CMTimeDebugTool.swift
//  TuneWave
//
//  Created by Yukun Li on 2025/4/12.
//

import Foundation
import CoreMedia

func humanReadableTime(from cmTime: CMTime) -> String {
    // 确保时间有效
    guard cmTime.isValid && !cmTime.isIndefinite && !cmTime.isNegativeInfinity && !cmTime.isPositiveInfinity else {
        return cmTime.isValid ? "有效但特殊时间值" : "无效时间"
    }
    
    // 转换为秒
    let seconds = CMTimeGetSeconds(cmTime)
    
    // 处理异常情况
    if seconds.isNaN || seconds.isInfinite {
        return "无法计算的时间值"
    }
    
    // 使用不同格式，根据时间长度
    if seconds < 60 {
        // 少于1分钟: 显示为秒和毫秒
        return String(format: "%.2f秒", seconds)
    } else if seconds < 3600 {
        // 少于1小时: 显示为分:秒
        let minutes = Int(seconds / 60)
        let remainingSeconds = Int(seconds.truncatingRemainder(dividingBy: 60))
        return String(format: "%d:%02d", minutes, remainingSeconds)
    } else {
        // 大于等于1小时: 显示为时:分:秒
        let hours = Int(seconds / 3600)
        let minutes = Int((seconds.truncatingRemainder(dividingBy: 3600)) / 60)
        let remainingSeconds = Int(seconds.truncatingRemainder(dividingBy: 60))
        return String(format: "%d:%02d:%02d", hours, minutes, remainingSeconds)
    }
}

// 附加功能：可以自定义格式的版本
func humanReadableTime(from cmTime: CMTime, format: CMTimeFormat = .default) -> String {
    guard cmTime.isValid && !cmTime.isIndefinite && !cmTime.isPositiveInfinity && !cmTime.isNegativeInfinity else {
        return "特殊时间值"
    }
    
    let seconds = CMTimeGetSeconds(cmTime)
    
    if seconds.isNaN || seconds.isInfinite {
        return "无法计算的时间值"
    }
    
    switch format {
    case .seconds:
        return String(format: "%.2f秒", seconds)
        
    case .minutesAndSeconds:
        let minutes = Int(seconds / 60)
        let secs = Int(seconds.truncatingRemainder(dividingBy: 60))
        return String(format: "%d分%d秒", minutes, secs)
        
    case .hoursMinutesSeconds:
        let hours = Int(seconds / 3600)
        let minutes = Int((seconds.truncatingRemainder(dividingBy: 3600)) / 60)
        let secs = Int(seconds.truncatingRemainder(dividingBy: 60))
        return String(format: "%d小时%d分%d秒", hours, minutes, secs)
        
    case .colonFormat:
        let hours = Int(seconds / 3600)
        let minutes = Int((seconds.truncatingRemainder(dividingBy: 3600)) / 60)
        let secs = Int(seconds.truncatingRemainder(dividingBy: 60))
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
        
    case .default:
        if seconds < 60 {
            return String(format: "%.2f秒", seconds)
        } else if seconds < 3600 {
            let minutes = Int(seconds / 60)
            let secs = Int(seconds.truncatingRemainder(dividingBy: 60))
            return String(format: "%d:%02d", minutes, secs)
        } else {
            let hours = Int(seconds / 3600)
            let minutes = Int((seconds.truncatingRemainder(dividingBy: 3600)) / 60)
            let secs = Int(seconds.truncatingRemainder(dividingBy: 60))
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        
    case .milliseconds:
        return String(format: "%.3f秒", seconds)
    }
}

// 可用的格式枚举
enum CMTimeFormat {
    case `default`     // 根据时长自动选择合适的格式
    case seconds       // 仅显示秒
    case milliseconds  // 显示秒和毫秒
    case minutesAndSeconds  // 显示分和秒
    case hoursMinutesSeconds  // 显示时、分、秒
    case colonFormat   // 使用冒号格式 (00:00:00)
}

// 使用示例
fileprivate
func examples() {
    // 创建几个CMTime实例进行测试
    let time1 = CMTimeMakeWithSeconds(45.723, preferredTimescale: 600)  // 45.723秒
    let time2 = CMTimeMakeWithSeconds(156.5, preferredTimescale: 600)   // 2分36.5秒
    let time3 = CMTimeMakeWithSeconds(7825.25, preferredTimescale: 600) // 2小时10分25.25秒
    
    // 使用默认格式
    print("时间1: \(humanReadableTime(from: time1))")
    print("时间2: \(humanReadableTime(from: time2))")
    print("时间3: \(humanReadableTime(from: time3))")
    
    // 使用不同的格式
    print("时间3 (秒格式): \(humanReadableTime(from: time3, format: .seconds))")
    print("时间3 (分秒格式): \(humanReadableTime(from: time3, format: .minutesAndSeconds))")
    print("时间3 (时分秒格式): \(humanReadableTime(from: time3, format: .hoursMinutesSeconds))")
    print("时间3 (冒号格式): \(humanReadableTime(from: time3, format: .colonFormat))")
    print("时间3 (毫秒格式): \(humanReadableTime(from: time3, format: .milliseconds))")
}
