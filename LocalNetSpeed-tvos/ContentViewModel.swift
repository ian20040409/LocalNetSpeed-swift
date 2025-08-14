import Foundation
import Combine

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
    
    // tvOS-specific properties
    @Published var manualHost: String = ""
    @Published var isEditingHost = false
    
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
            let targetHost = getTargetHost()
            guard !targetHost.trimmingCharacters(in: .whitespaces).isEmpty else {
                progressText = "請輸入伺服器 IP"
                isRunning = false
                return
            }
            guard let size = Int(sizeMB), size > 0 else {
                progressText = "資料大小不正確"
                isRunning = false
                return
            }
            append("客戶端連線到 \(targetHost):\(p)，傳送 \(size) MB...")
            tester?.runClient(host: targetHost,
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
    
    func clearPresetSelection() {
        host = ""
        manualHost = ""
        isEditingHost = false
    }
    
    func finishManualInput() {
        isEditingHost = false
        
        // 驗證 IP 地址格式
        let trimmedHost = manualHost.trimmingCharacters(in: .whitespaces)
        guard !trimmedHost.isEmpty else {
            progressText = "請輸入 IP 地址"
            return
        }
        
        guard isValidIPAddress(trimmedHost) else {
            progressText = "IP 地址格式不正確，請輸入有效的 IPv4 地址（例如：192.168.1.1）"
            return
        }
        
        // 設定目標主機並清除手動輸入
        host = trimmedHost
        manualHost = trimmedHost // 確保顯示的是標準化的 IP
        
        // 在客戶端模式下立即開始測試
        if mode == .client {
            progressText = "IP 地址已確認，開始測試..."
            start()
        }
    }
    
    // 驗證 IPv4 地址格式
    private func isValidIPAddress(_ ip: String) -> Bool {
        let components = ip.split(separator: ".").map(String.init)
        
        // 必須有四個部分
        guard components.count == 4 else { return false }
        
        // 每個部分必須是 0-255 的數字
        for component in components {
            guard let number = Int(component),
                  number >= 0 && number <= 255,
                  String(number) == component else { // 防止前導零
                return false
            }
        }
        
        return true
    }
    
    func getTargetHost() -> String {
        if isEditingHost || !manualHost.isEmpty {
            return manualHost
        } else {
            return host
        }
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
