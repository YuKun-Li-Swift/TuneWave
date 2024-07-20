//
//  NeverError.swift
//  TuneWave Watch App
//
//  Created by Yukun Li on 2024/7/15.
//

import Foundation

enum NeverError:Error,LocalizedError {
    case neverError
    var errorDescription: String? {
        switch self {
        case .neverError:
            "APP遇到了未知错误，此错误没有已知的原因和解决方法，"+DeveloperContactGenerator.generate()
        }
    }
}
