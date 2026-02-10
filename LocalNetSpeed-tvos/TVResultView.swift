import SwiftUI

struct TVResultView: View {
    let result: SpeedTestResult
    let unit: ContentViewModel.SpeedUnit
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 40) {
            Text("測試結果")
                .font(.system(size: 48, weight: .bold))
            
            VStack(spacing: 30) {
                let speedVal = unit.convert(fromMBps: result.speedMBps)
                let maxSpeed: Double = {
                    switch unit {
                    case .mbps: return 1000
                    case .gbps: return 1
                    case .mbs: return 125
                    case .kbps: return 1_000_000
                    }
                }()
                
                // Speed Gauge
                SpeedGaugeView(
                    speed: speedVal,
                    unit: unit.rawValue,
                    maxSpeed: maxSpeed
                )
                
                // Evaluation
                Text(result.evaluation.rating)
                    .font(.system(size: 40, weight: .semibold))
                
                // Stats
                VStack(spacing: 20) {
                    HStack(spacing: 60) {
                        VStack(spacing: 8) {
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.title2)
                                .foregroundColor(.accentColor)
                            Text("傳輸量")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text("\(String(format: "%.2f", Double(result.transferredBytes)/1024/1024)) MB")
                                .font(.title2)
                                .fontWeight(.medium)
                        }
                        VStack(spacing: 8) {
                            Image(systemName: "clock")
                                .font(.title2)
                                .foregroundColor(.accentColor)
                            Text("耗時")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text("\(String(format: "%.2f", result.duration)) 秒")
                                .font(.title2)
                                .fontWeight(.medium)
                        }
                        VStack(spacing: 8) {
                            Image(systemName: "chart.bar")
                                .font(.title2)
                                .foregroundColor(.accentColor)
                            Text("達成率")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text("\(String(format: "%.1f", result.evaluation.performancePercent))%")
                                .font(.title2)
                                .fontWeight(.medium)
                        }
                    }
                }
            }
            .padding(40)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 30))
            
            Button("關閉") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
    }
}
