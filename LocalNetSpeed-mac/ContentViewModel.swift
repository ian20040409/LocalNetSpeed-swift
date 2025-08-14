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
    @Published var serverConnectionCount = 0
    
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
    }
    
    func clearLog() {
        log = ""
    }
    
    private func handleCompletion(_ res: Result<SpeedTestResult, Error>) {
        isRunning = false
        switch res {
        case .success(let r):
            result = r
            progressText = "完成"
            append(format(r))
        case .failure(let e):
            let errorMessage = formatError(e)
            progressText = "錯誤：\(errorMessage)"
            append("錯誤：\(errorMessage)")
            
            // 如果是權限錯誤，提供額外建議
            if errorMessage.contains("Operation not permitted") || errorMessage.contains("權限") {
                append("建議解決方案：")
                append("1. 檢查系統防火牆設定")
                append("2. 嘗試使用不同埠號（如 8080）")
                append("3. 確認 App 具有網路權限")
            }
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
    
    private func formatError(_ error: Error) -> String {
        let nsError = error as NSError
        
        // 處理常見的網路權限錯誤
        if nsError.domain == NSPOSIXErrorDomain && nsError.code == 1 {
            return "網路權限被拒絕"
        }
        
        // 處理其他常見錯誤
        switch nsError.code {
        case 48: // Address already in use
            return "埠號已被使用，請嘗試其他埠號"
        case 49: // Can't assign requested address
            return "無法綁定指定位址"
        case 61: // Connection refused
            return "連線被拒絕，請檢查伺服器是否正在執行"
        case 65: // No route to host
            return "無法連線到主機，請檢查網路連線"
        default:
            return nsError.localizedDescription
        }
    }
}