import Foundation

struct GigabitEvaluation: Equatable {
    let speedMBps: Double
    let performancePercent: Double
    let rating: String
    let message: String
    let suggestions: [String]
}

enum GigabitEvaluator {
    static let theoreticalMBps: Double = 125.0
    static let practicalThreshold: Double = 100.0
    
    static func evaluate(speedMBps: Double) -> GigabitEvaluation {
        let percent = speedMBps / theoreticalMBps * 100.0
        let (rating, message): (String, String)
        switch speedMBps {
        case let v where v >= practicalThreshold:
            (rating, message) = ("優秀 ✅", "恭喜！您的網路已達到 Gigabit 等級效能")
        case 80..<practicalThreshold:
            (rating, message) = ("良好 ⚡", "接近 Gigabit 效能，但仍有提升空間")
        case 50..<80:
            (rating, message) = ("一般 ⚠️", "網路速度一般，建議檢查網路設備或連線品質")
        case 10..<50:
            (rating, message) = ("偏慢 🐌", "網路速度偏慢，可能未使用 Gigabit 設備")
        default:
            (rating, message) = ("很慢 🚫", "網路速度很慢，建議檢查網路連線問題")
        }
        var suggestions: [String] = []
        if speedMBps < practicalThreshold {
            suggestions = [
                "確認使用 Cat5e 或更高等級的網路線",
                "檢查網路交換器是否支援 Gigabit",
                "確認網路卡設定為 1000 Mbps 全雙工",
                "關閉不必要的網路程式和服務",
                "檢查是否有網路瓶頸或干擾"
            ]
        }
        return GigabitEvaluation(
            speedMBps: speedMBps,
            performancePercent: percent,
            rating: rating,
            message: message,
            suggestions: suggestions
        )
    }
}