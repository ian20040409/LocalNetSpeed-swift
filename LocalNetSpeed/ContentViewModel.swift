import Foundation
import Combine  // ← 加上這行

@MainActor
final class ContentViewModel: ObservableObject {
    @Published var mode: SpeedTestMode = .server
    @Published var host: String = ""
    @Published var port: String = "65432"
    @Published var sizeMB: String = "100"
    @Published var isRunning = false
    @Published var progressText = "尚未開始"
    @Published var log = ""
    @Published var result: SpeedTestResult?
    
    private var tester: SpeedTester?
    
    func start() {
        guard !isRunning else { return }
        result = nil
        log = ""
        progressText = "準備中..."
        
        guard let p = UInt16(port) else {
            progressText = "埠號不正確"
            return
        }
        tester = SpeedTester()
        isRunning = true
        
        switch mode {
        case .server:
            append("伺服器啟動，埠 \(p)，等待連線...")
            tester?.runServer(port: p,
                              progress: { [weak self] bytes in
                Task { @MainActor in
                    let mb = Double(bytes)/1024/1024
                    self?.progressText = String(format: "已接收 %.1f MB", mb)
                }
            }, completion: { [weak self] res in
                Task { @MainActor in self?.handleCompletion(res) }
            })
        case .client:
            guard !host.trimmingCharacters(in: .whitespaces).isEmpty else {
                progressText = "請輸入伺服器 IP"
                isRunning = false
                return
            }
            guard let size = Int(sizeMB), size > 0 else {
                progressText = "資料大小不正確"
                isRunning = false
                return
            }
            append("客戶端連線到 \(host):\(p)，傳送 \(size) MB...")
            tester?.runClient(host: host,
                              port: p,
                              totalSizeMB: size,
                              progress: { [weak self] sent in
                Task { @MainActor in
                    let percent = Double(sent)/Double(size*1024*1024)*100
                    self?.progressText = String(format: "進度 %.1f%%", percent)
                }
            }, completion: { [weak self] res in
                Task { @MainActor in self?.handleCompletion(res) }
            })
        }
    }
    
    func cancel() {
        tester?.cancel()
        isRunning = false
        progressText = "已取消"
        append("測試已取消")
    }
    
    private func handleCompletion(_ res: Result<SpeedTestResult, Error>) {
        isRunning = false
        switch res {
        case .success(let r):
            result = r
            progressText = "完成"
            append(format(r))
        case .failure(let e):
            progressText = "錯誤：\(e.localizedDescription)"
            append("錯誤：\(e)")
        }
    }
    
    private func append(_ line: String) {
        if log.isEmpty {
            log = line
        } else {
            log.append("\n\(line)")
        }
    }
    
    private func format(_ r: SpeedTestResult) -> String {
        let eval = r.evaluation
        let totalMB = String(format: "%.2f", Double(r.transferredBytes)/1024/1024)
        let durationStr = String(format: "%.2f", r.duration)
        let speedStr = String(format: "%.2f", r.speedMBps)
        let evalSpeed = String(format: "%.2f", eval.speedMBps)
        let percentStr = String(format: "%.1f", eval.performancePercent)
        
        var lines: [String] = []
        lines.append("--- 測試結果 ---")
        lines.append("總量: \(totalMB) MB")
        lines.append("耗時: \(durationStr) 秒")
        lines.append("平均: \(speedStr) MB/s")
        lines.append("")
        lines.append("--- Gigabit 評估 ---")
        lines.append("實際速度: \(evalSpeed) MB/s")
        lines.append("理論: \(GigabitEvaluator.theoreticalMBps) MB/s")
        lines.append("達成比例: \(percentStr) %")
        lines.append("評級: \(eval.rating)")
        lines.append("建議: \(eval.message)")
        if !eval.suggestions.isEmpty {
            lines.append("改善建議:")
            eval.suggestions.forEach { lines.append("• \($0)") }
        }
        return lines.joined(separator: "\n")
    }
}
