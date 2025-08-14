import SwiftUI
import Network

struct ContentView: View {
    @StateObject private var vm = ContentViewModel()
    @FocusState private var focusedButton: FocusableButton?
    @State private var localIP = "獲取中..."

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
                        VStack(spacing: 20) {
                            HStack(spacing: 15) {
                                Text("目標 IP:")
                                    .font(.title3)
                                    
                                
                                TextField("192.168.x.x", text: $vm.manualHost)
                                    .font(.title3)
                                    .frame(width: 500)
                                    .focused($focusedButton, equals: .manualInput)
                                    .onSubmit {
                                        vm.finishManualInput()
                                    }
                            }
                            
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
                                
                                // 顯示當前選中的 IP
                                VStack(spacing: 5) {
                                    Text("目標伺服器")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(vm.getTargetHost())
                                        .font(.title3)
                                        .fontWeight(.bold)
                                        .foregroundColor(.green)
                                }
                                .padding()
                                .background(.thinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
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
                    VStack(spacing: 25) {
                        Text("測試結果").font(.title).fontWeight(.bold)
                        VStack(spacing: 20) {
                            VStack(spacing: 10) {
                                Text("網路速度").font(.title2).foregroundColor(.secondary)
                                Text("\(String(format: "%.2f", result.speedMBps)) MB/s").font(.system(size: 72, weight: .bold)).foregroundColor(.green)
                            }
                            VStack(spacing: 10) {
                                Text("效能評級").font(.title2).foregroundColor(.secondary)
                                Text(result.evaluation.rating).font(.system(size: 36, weight: .semibold)).foregroundColor(.primary)
                            }
                            VStack(spacing: 15) {
                                HStack(spacing: 40) {
                                    VStack { Text("傳輸量").font(.caption).foregroundColor(.secondary); Text("\(String(format: "%.2f", Double(result.transferredBytes)/1024/1024)) MB").font(.title3).fontWeight(.medium) }
                                    VStack { Text("耗時").font(.caption).foregroundColor(.secondary); Text("\(String(format: "%.2f", result.duration)) 秒").font(.title3).fontWeight(.medium) }
                                    VStack { Text("達成率").font(.caption).foregroundColor(.secondary); Text("\(String(format: "%.1f", result.evaluation.performancePercent))%").font(.title3).fontWeight(.medium) }
                                }
                            }
                        }
                        .padding(30).background(.thinMaterial).clipShape(RoundedRectangle(cornerRadius: 25))
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
        .onChange(of: vm.isRunning) { _, isRunning in
            // 當測試開始運行時，將焦點移到停止按鈕
            if isRunning {
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
