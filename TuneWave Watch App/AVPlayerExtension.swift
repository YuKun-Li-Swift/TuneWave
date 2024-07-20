//
//  AVPlayerExtension.swift
//  TuneWave Watch App
//
//  Created by Yukun Li on 2024/7/19.
//

import Foundation
import AVFoundation
import MediaPlayer

enum NowPlaySeekError: Error {
    case noCurrentItem
    
    func toMPRemoteCommandHandlerStatus() -> MPRemoteCommandHandlerStatus {
        switch self {
        case .noCurrentItem:
            return .noSuchContent
        }
    }
}

extension AVPlayer {
    
    func add10Seconds() throws {
        guard let currentItem = self.currentItem else {
            throw NowPlaySeekError.noCurrentItem
        }
        
        let currentTime = self.currentTime()
        let newTime = currentTime.seconds + 10
        let maxTime = currentItem.duration.seconds
        
        let finalTime = newTime <= maxTime ? newTime : maxTime
        
        self.seek(to: CMTime(seconds: finalTime, preferredTimescale: 60))
    }
    
    func subtract10Seconds() throws {
        guard let currentItem = self.currentItem else {
            throw NowPlaySeekError.noCurrentItem
        }
        
        let currentTime = self.currentTime()
        let newTime = currentTime.seconds - 10
        
        let finalTime = newTime >= 0 ? newTime : 0
        
        self.seek(to: CMTime(seconds: finalTime, preferredTimescale: 60))
    }
}
