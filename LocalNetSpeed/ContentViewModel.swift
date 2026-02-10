import Foundation
import Combine  // ← 加上這行

#if os(iOS)
import UIKit
#endif

@MainActor
final class ContentViewModel: ObservableObject {
    @Published var mode: SpeedTestMode = .server
    @Published var selectedUnit: SpeedUnit = .mbps
    @Published var host: String = ""
    @Published var port: String = "65432"
    @Published var sizeMB: String = "100"
    @Published var isRunning = false
    @Published var progressText = "尚未開始"

    @Published var log = ""
    @Published var result: SpeedTestResult?

    enum SpeedUnit: String, CaseIterable, Identifiable {
        case mbps = "Mbps"
        case gbps = "Gbps"
        case mbs = "MB/s"
        case kbps = "Kbps"
        
        var id: String { rawValue }
        
        func convert(fromMBps mbps: Double) -> Double {
            switch self {
            case .mbps: return mbps * 8
            case .gbps: return mbps * 8 / 1024
            case .mbs: return mbps
            case .kbps: return mbps * 8 * 1024
            }
        }
    }
    @Published var serverConnectionCount = 0
    @Published var enableRetry = true  // 控制是否啟用重試機制
    
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
            serverConnectionCount = 0
            append("伺服器啟動，埠 \(p)，等待連線...")
            tester?.runServer(port: p,
                              progress: { [weak self] bytes in
                Task { @MainActor in
                    let mb = Double(bytes)/1024/1024
                    self?.progressText = String(format: "已接收 %.1f MB", mb)
                }
            }, completion: { [weak self] res in
                Task { @MainActor in self?.handleCompletion(res) }
            }, onNewConnection: { [weak self] count in
                Task { @MainActor in
                    self?.serverConnectionCount = count
                    self?.append("新連線 #\(count)")
                }
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
                    // 這裡可以選擇是否也要顯示即時速度，暫時維持百分比
                    // 如果要顯示即時速度，需要計算 delta
                    self?.progressText = String(format: "進度 %.1f%%", percent)
                }
            }, completion: { [weak self] res in
                Task { @MainActor in self?.handleCompletion(res) }
            }, retryStatus: { [weak self] attempt, maxAttempts in
                Task { @MainActor in
                    if attempt == 1 {
                        self?.progressText = "正在連線..."
                    } else if attempt <= 5 {
                        self?.progressText = "重試連線 (\(attempt)/\(maxAttempts))..."
                        self?.append("第 \(attempt) 次連線嘗試...")
                    } else {
                        self?.progressText = "等待伺服器啟動... (\(attempt)/\(maxAttempts))"
                        if attempt % 5 == 0 {  // 每5次重試記錄一次
                            self?.append("持續等待伺服器啟動... (第 \(attempt) 次嘗試)")
                        }
                    }
                }
            }, enableRetry: enableRetry)
        }
    }
    
    func cancel() {
        tester?.cancel()
        isRunning = false
        progressText = "已取消"
        append("測試已取消")
        
        if mode == .server {
            serverConnectionCount = 0
        }
    }
    
    func forceStopServer() {
        tester?.cancel()
        tester = nil
        isRunning = false
        serverConnectionCount = 0
        progressText = "伺服器已強制停止"
        append("伺服器已強制停止")
        
        #if os(iOS)
        Haptic.Impact.heavy()
        #endif
    }
    
    private func handleCompletion(_ res: Result<SpeedTestResult, Error>) {
        switch res {
        case .success(let r):
            result = r
            #if os(iOS)
            Haptic.success()
            #endif
            if mode == .server {
                // 伺服器模式：測試完成後繼續運行，等待下一個連線
                progressText = "等待連線..."
                append(format(r))
                append("--- 伺服器繼續運行，等待下一個連線 ---")
            } else {
                // 客戶端模式：測試完成後停止
                isRunning = false
                progressText = "完成"
                append(format(r))
            }
        case .failure(let e):
            #if os(iOS)
            Haptic.error()
            #endif
            if mode == .server {
                // 伺服器模式：錯誤後繼續運行
                progressText = "等待連線..."
                append("錯誤：\(e.localizedDescription)")
                append("--- 伺服器繼續運行，等待下一個連線 ---")
            } else {
                // 客戶端模式：錯誤後停止
                isRunning = false
                progressText = "錯誤：\(e.localizedDescription)"
                append("錯誤：\(e)")
            }
        }
    }
    
    func clearLog() {
        log = ""
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
        let val = selectedUnit.convert(fromMBps: r.speedMBps)
        let speedStr = String(format: "%.2f", val)
        let unitStr = selectedUnit.rawValue
        
        let evalSpeedVal = selectedUnit.convert(fromMBps: eval.speedMBps)
        let evalSpeed = String(format: "%.2f", evalSpeedVal)
        
        let theoreticalVal = selectedUnit.convert(fromMBps: GigabitEvaluator.theoreticalMBps)
        let theoreticalStr = String(format: "%.0f", theoreticalVal)
        
        let percentStr = String(format: "%.1f", eval.performancePercent)
        
        var lines: [String] = []
        lines.append("--- 測試結果 ---")
        lines.append("總量: \(totalMB) MB")
        lines.append("耗時: \(durationStr) 秒")
        lines.append("平均: \(speedStr) \(unitStr)")
        lines.append("")
        lines.append("--- Gigabit 評估 ---")
        lines.append("實際速度: \(evalSpeed) \(unitStr)")
        lines.append("理論: \(theoreticalStr) \(unitStr)")
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
