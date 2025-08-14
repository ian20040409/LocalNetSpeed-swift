import SwiftUI
import Network

// MARK: - 統計卡片視圖
struct StatisticCardView: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 15)
        .padding(.horizontal, 8)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

struct ContentView: View {
    @StateObject private var vm = ContentViewModel()
    @FocusState private var focusedButton: FocusableButton?
    @State private var localIP = "獲取中..."
    @State private var isShowingIPInputView = false

    enum FocusableButton {
        case modeSelection
        case manualInput, clearSelection
        case startStop, forceStop
        case clearLog
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                // 標題區域
                Text("區域網路速度測試")
                    .font(.system(size: 30))
                    .foregroundColor(.primary)
                    .padding(.top, 10)
                
                // 本機 IP 顯示區域
                VStack(spacing: 15) {
                    Text("本機 IP 位址")
                        .font(.title3)
                        .fontWeight(.semibold)
                        
                    
                    HStack(spacing: 20) {
                        Text(localIP)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(localIP == "獲取中..." || localIP == "無法取得" ? .secondary : .green)
                            .padding()
                            
                            .clipShape(RoundedRectangle(cornerRadius: 15))
                        
                        Button("重新整理") {
                            getLocalIPAddress()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                        .tint(.blue)
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20))

                // 模式選擇區域
                VStack(spacing: 15) {
                   
                    
                    Picker("測試模式", selection: $vm.mode) {
                        ForEach(SpeedTestMode.allCases) { mode in
                            Label(mode.rawValue, systemImage: icon(for: mode))
                                .tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 600)
                    .focused($focusedButton, equals: .modeSelection)
                }

                // 客戶端模式的伺服器選擇
                if vm.mode == .client {
                    VStack(spacing: 30) {
                        Text("輸入目標伺服器 IP")
                            
                        
                        // 手動輸入區域
                        /*
                        VStack(spacing: 20) {
                            HStack(spacing: 15) {
                                TextField("目標 IP:", text: $vm.manualHost)
                                    .font(.title3)
                                    .frame(width: 500)
                                    .focused($focusedButton, equals: .manualInput)
                                        .onSubmit {
                                            vm.finishManualInput()
                                            vm.start()           // 接著立即開始測試

                                        }
                            }
                          */
                        
                        // 在 ContentView 的 if vm.mode == .client { ... } 內部

                        // ... 原本的 VStack ...
                        VStack(spacing: 20) {
                            // 用一個 HStack 來顯示當前 IP 並提供一個編輯按鈕
                            HStack {
                                Text("目標 IP: \(vm.manualHost.isEmpty ? "尚未設定" : vm.manualHost)")
                                    .font(.title3)

                                Button("編輯") {
                                    isShowingIPInputView = true
                                }
                                .focused($focusedButton, equals: .manualInput)
                            }
                        
                        .padding()
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        // 使用 .sheet 來彈出全螢幕的 IP 輸入畫面
                        .sheet(isPresented: $isShowingIPInputView) {
                            IPInputView { ipString in
                                // 當在 IPInputView 按下 "Done" 時，會執行這裡的程式碼
                                vm.manualHost = ipString // 更新 ViewModel
                                vm.finishManualInput()   // 呼叫原本的函式來確認 IP
                                isShowingIPInputView = false // 關閉輸入畫面
                                vm.start() // 自動開始測試
                            }
                        }
                        // ... 後續的程式碼 ...
                        
                            VStack(spacing: 12) {
                                if localIP != "獲取中..." && localIP != "無法取得" {
                                    VStack(spacing: 8) {
                                        Text("本機 IP: \(localIP)")
                                            .font(.callout)
                                            .foregroundColor(.green)
                                            .fontWeight(.medium)
                                        Text("請輸入其他裝置的 IP 位址進行測試")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                               
                            }
                        }
                        .padding()
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 20))

                        // 清除選擇按鈕
                        if !vm.getTargetHost().isEmpty {
                            HStack(spacing: 20) {
                                Button("清除輸入") {
                                    vm.clearPresetSelection()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.large)
                                .focused($focusedButton, equals: .clearSelection)
                                
                                
                            }
                        }
                    }
                }
                
                // 伺服器狀態顯示
                if vm.mode == .server && vm.isRunning {
                    VStack(spacing: 15) {
                        Text("伺服器狀態")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        VStack(spacing: 20) {
                            // 連線資訊
                            if localIP != "獲取中..." && localIP != "無法取得" {
                                VStack(spacing: 8) {
                                    Text("伺服器位址")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("\(localIP):\(vm.port)")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.blue)
                                }
                                .padding()
                                .background(.blue.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            
                            // 狀態資訊
                            HStack(spacing: 30) {
                                VStack {
                                    Text("埠號")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(vm.port)
                                        .font(.title2)
                                        .fontWeight(.bold)
                                }
                                VStack {
                                    Text("連線數")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("\(vm.serverConnectionCount)")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.green)
                                }
                            }
                        }
                        .padding()
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 15))
                    }
                }

                // 進度顯示
                VStack(spacing: 20) {
                    Text("測試狀態")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text(vm.progressText)
                        .font(.title3)
                        .foregroundColor(vm.isRunning ? .blue : .secondary)
                        .padding()
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 15))
                        .frame(minWidth: 400)
                }

                // 結果顯示
                if let result = vm.result {
                    VStack(spacing: 30) {
                        // 標題區域
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.green)
                            Text("測試結果")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                        }
                        
                        VStack(spacing: 35) {
                            // 主要速度顯示區域
                            VStack(spacing: 15) {
                                HStack {
                                    Image(systemName: "speedometer")
                                        .font(.title2)
                                        .foregroundColor(.blue)
                                    Text("網路速度")
                                        .font(.title2)
                                        .foregroundColor(.secondary)
                                }
                                
                                Text("\(String(format: "%.2f", result.speedMBps)) MB/s")
                                    .font(.system(size: 80, weight: .bold, design: .rounded))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.green, .blue],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .shadow(color: .green.opacity(0.3), radius: 8, x: 0, y: 4)
                            }
                            .padding(25)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(.green.opacity(0.3), lineWidth: 2)
                                    )
                            )
                            
                            // 效能評級區域
                            VStack(spacing: 15) {
                                HStack {
                                    Image(systemName: "star.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.orange)
                                    Text("效能評級")
                                        .font(.title2)
                                        .foregroundColor(.secondary)
                                }
                                
                                Text(result.evaluation.rating)
                                    .font(.system(size: 42, weight: .semibold))
                                    .foregroundColor(.primary)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .fill(ratingBackgroundColor(for: result.evaluation.rating))
                                            .opacity(0.2)
                                    )
                                
                                Text(result.evaluation.message)
                                    .font(.title3)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(nil)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(25)
                            .background(.thinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            
                            // 詳細統計區域
                            VStack(spacing: 25) {
                                HStack {
                                    Image(systemName: "chart.bar.fill")
                                        .font(.title2)
                                        .foregroundColor(.purple)
                                    Text("詳細統計")
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                    Spacer()
                                }
                                
                                // 第一行統計
                                HStack(spacing: 30) {
                                    StatisticCardView(
                                        icon: "arrow.up.circle.fill",
                                        title: "傳輸量",
                                        value: "\(String(format: "%.2f", Double(result.transferredBytes)/1024/1024)) MB",
                                        color: .blue
                                    )
                                    
                                    StatisticCardView(
                                        icon: "clock.fill",
                                        title: "耗時",
                                        value: "\(String(format: "%.2f", result.duration)) 秒",
                                        color: .orange
                                    )
                                    
                                    StatisticCardView(
                                        icon: "percent",
                                        title: "達成率",
                                        value: "\(String(format: "%.1f", result.evaluation.performancePercent))%",
                                        color: .green
                                    )
                                }
                                
                                // 第二行統計
                                HStack(spacing: 30) {
                                    StatisticCardView(
                                        icon: "gauge.high",
                                        title: "理論速度",
                                        value: "\(String(format: "%.0f", GigabitEvaluator.theoreticalMBps)) MB/s",
                                        color: .gray
                                    )
                                    
                                    StatisticCardView(
                                        icon: "calendar.badge.clock",
                                        title: "開始時間",
                                        value: formatTime(result.startedAt),
                                        color: .purple
                                    )
                                    
                                    StatisticCardView(
                                        icon: "stopwatch.fill",
                                        title: "結束時間",
                                        value: formatTime(result.endedAt),
                                        color: .purple
                                    )
                                }
                            }
                            .padding(25)
                            .background(.thinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            
                            // 建議區域
                            if !result.evaluation.suggestions.isEmpty {
                                VStack(spacing: 20) {
                                    HStack {
                                        Image(systemName: "lightbulb.fill")
                                            .font(.title2)
                                            .foregroundColor(.yellow)
                                        Text("改善建議")
                                            .font(.title2)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.primary)
                                        Spacer()
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 15) {
                                        ForEach(Array(result.evaluation.suggestions.enumerated()), id: \.offset) { index, suggestion in
                                            HStack(alignment: .top, spacing: 15) {
                                                Image(systemName: "checkmark.circle")
                                                    .font(.title3)
                                                    .foregroundColor(.green)
                                                    .frame(width: 24)
                                                
                                                Text(suggestion)
                                                    .font(.callout)
                                                    .foregroundColor(.primary)
                                                    .lineLimit(nil)
                                                    .fixedSize(horizontal: false, vertical: true)
                                                
                                                Spacer()
                                            }
                                        }
                                    }
                                }
                                .padding(25)
                                .background(.yellow.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(.yellow.opacity(0.3), lineWidth: 2)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                            }
                        }
                    }
                }

                // 控制按鈕區域
                VStack(spacing: 30) {
                    // 主要控制按鈕
                    Button(vm.isRunning ? "停止測試" : "開始測試") {
                        vm.isRunning ? vm.cancel() : vm.start()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .font(.system(size: 24, weight: .semibold))
                    .tint(vm.isRunning ? .red : .blue)
                    .focused($focusedButton, equals: .startStop)
                    
                    // 伺服器強制停止按鈕
                    if vm.mode == .server && vm.isRunning {
                        Button("強制停止伺服器") {
                            vm.forceStopServer()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .font(.title3)
                        .tint(.orange)
                        .focused($focusedButton, equals: .forceStop)
                    }
                    
                    // 清除記錄按鈕
                    if !vm.log.isEmpty {
                        Button("清除記錄") {
                            vm.clearLog()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                        .font(.title3)
                        .tint(.gray)
                        .focused($focusedButton, equals: .clearLog)
                    }
                }
                
                Spacer(minLength: 50)
            }
            .padding(.horizontal, 60)
        }
        .onAppear {
            // 設定初始焦點
            focusedButton = .modeSelection
            // 獲取本機 IP
            getLocalIPAddress()
        }
        .onChange(of: vm.mode) { _, newMode in
            // 當模式改變時，自動設定焦點到相應區域
            if newMode == .client {
                focusedButton = .manualInput
            } else {
                focusedButton = .startStop
            }
        }
    }
    
    
    // 輔助函數：根據模式返回圖示名稱
    private func icon(for mode: SpeedTestMode) -> String {
        switch mode {
        case .server:
            return "server.rack"
        case .client:
            return "iphone"
        }
    }
    
    // 輔助函數：根據評級返回背景色
    private func ratingBackgroundColor(for rating: String) -> Color {
        if rating.contains("優秀") { return .green }
        else if rating.contains("良好") { return .blue }
        else if rating.contains("一般") { return .orange }
        else if rating.contains("偏慢") { return .red }
        else if rating.contains("很慢") { return .red }
        else { return .gray }
    }
    
    // 輔助函數：格式化時間
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
    
    // 獲取本機 IP 位址
    private func getLocalIPAddress() {
        Task {
            let ip = await LocalIPHelper.getLocalIPAddress()
            await MainActor.run {
                self.localIP = ip
            }
        }
    }
}

// MARK: - 本機 IP 取得工具
struct LocalIPHelper {
    static func getLocalIPAddress() async -> String {
        return await withCheckedContinuation { continuation in
            let monitor = NWPathMonitor()
            monitor.pathUpdateHandler = { path in
                var result = "無法取得"
                
                // 使用 path.availableInterfaces 找到有效介面
                for interface in path.availableInterfaces {
                    if interface.type == .wifi || interface.type == .wiredEthernet {
                        // 嘗試取得該介面的 IP
                        if let ip = getIPAddress(for: interface) {
                            result = ip
                            break
                        }
                    }
                }
                
                // 如果上述方法沒找到，使用傳統方法
                if result == "無法取得" {
                    result = getIPAddressTraditional()
                }
                
                monitor.cancel()
                continuation.resume(returning: result)
            }
            
            let queue = DispatchQueue(label: "NetworkMonitor")
            monitor.start(queue: queue)
        }
    }
    
    private static func getIPAddress(for interface: NWInterface) -> String? {
        // Network.framework 介面資訊較難直接取得 IP
        // 這裡回到傳統方法
        return nil
    }
    
    private static func getIPAddressTraditional() -> String {
        var address: String = "無法取得"
        var ifaddr: UnsafeMutablePointer<ifaddrs>? = nil
        
        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }
                
                let interface = ptr?.pointee
                let addrFamily = interface?.ifa_addr.pointee.sa_family
                
                if addrFamily == UInt8(AF_INET) {
                    // IPv4
                    let name = String(cString: (interface?.ifa_name)!)
                    
                    // 過濾有效的介面（排除 loopback）
                    if name == "en0" || name == "en1" || name.hasPrefix("en") && !name.contains("lo") {
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        let addr = interface?.ifa_addr
                        
                        if getnameinfo(addr, socklen_t((addr?.pointee.sa_len)!),
                                      &hostname, socklen_t(hostname.count),
                                      nil, socklen_t(0), NI_NUMERICHOST) == 0 {
                            address = String(cString: hostname)
                            break
                        }
                    }
                }
            }
            freeifaddrs(ifaddr)
        }
        
        return address
    }
}
