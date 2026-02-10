//
//  SpeedTestMode.swift
//  LocalNetSpeed-tvos
//
//  Created by 林恩佑 on 2025/8/14.
//


import Foundation

enum SpeedTestMode: String, CaseIterable, Identifiable {
    case server = "伺服器"
    case client = "客戶端"
    var id: String { rawValue }
}

struct SpeedTestResult: Equatable {
    let transferredBytes: Int
    let duration: TimeInterval
    var speedMBps: Double {
        guard duration > 0 else { return 0 }
        return (Double(transferredBytes)/1024/1024)/duration
    }
    let startedAt: Date
    let endedAt: Date
    let evaluation: GigabitEvaluation
}