import SwiftUI
import Network

struct ContentView: View {
    @StateObject private var vm = ContentViewModel()
    @State private var localIP = "獲取中..."
    @State private var showCopiedAlert = false
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            speedTestView
                .tabItem {
                    Label("本地測速", systemImage: "house.badge.wifi.fill")
                }
                .tag(0)
            
            FastComView()
                .tabItem {
                    Label("Fast.com", systemImage: "link.icloud.fill")
                }
                .tag(1)
        }
        .onAppear {
            getLocalIPAddress()
        }
        .alert("已複製", isPresented: $showCopiedAlert) {
            Button("確定") { }
        } message: {
            Text("IP 位址已複製到剪貼板")
        }
    }
    
    // 將原本的主要內容抽出為一個子 View
    private var speedTestView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("模式", selection: $vm.mode) {
                ForEach(SpeedTestMode.allCases) { m in
                    Text(m.rawValue).tag(m)
                }
            }
            .pickerStyle(.segmented)
            
            // 顯示本機 IP
            HStack {
                Text("本機 IP:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text(localIP)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .textSelection(.enabled)
                
                Spacer()
                
                Button(action: {
                    copyToClipboard(localIP)
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .help("複製 IP 位址")
                .disabled(localIP == "獲取中..." || localIP == "無法取得")
                
                Button("重新整理") {
                    getLocalIPAddress()
                }
                .font(.caption)
                .buttonStyle(.bordered)
            }
            .padding(.vertical, 4)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            if vm.mode == .client {
                TextField("伺服器 IP", text: $vm.host)
                    .textFieldStyle(.roundedBorder)
            }
            
            HStack {
                TextField("埠號", text: $vm.port)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 120)
                if vm.mode == .client {
                    TextField("資料大小 (MB)", text: $vm.sizeMB)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 140)
                }
                Spacer()
            }
            
            Picker("單位", selection: $vm.selectedUnit) {
                ForEach(ContentViewModel.SpeedUnit.allCases) { unit in
                    Text(unit.rawValue).tag(unit)
                }
            }
            .pickerStyle(.segmented)
            .padding(.bottom, 4)

            // 狀態顯示
            if vm.isRunning || (!vm.progressText.isEmpty && vm.progressText != "尚未開始") {
                HStack {
                    if vm.isRunning && vm.mode == .server {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(.green)
                                .frame(width: 8, height: 8)
                                .scaleEffect(vm.isRunning ? 1.0 : 0.5)
                                .animation(.easeInOut(duration: 1.0).repeatForever(), value: vm.isRunning)
                            Text("伺服器運行中")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.green)
                            
                            if vm.serverConnectionCount > 0 {
                                Text("(\(vm.serverConnectionCount) 連線)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                    }
                }
                
                Text(vm.progressText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if let r = vm.result {
                let speedVal = vm.selectedUnit.convert(fromMBps: r.speedMBps)
                Text("速度: \(String(format: "%.2f", speedVal)) \(vm.selectedUnit.rawValue)")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("日誌")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if !vm.log.isEmpty {
                        Button("清除") {
                            vm.clearLog()
                        }
                        .font(.caption2)
                        .buttonStyle(.bordered)
                    }
                }
                
                ScrollView {
                    Text(vm.log.isEmpty ? "尚無日誌記錄" : vm.log)
                        .font(.system(.footnote, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .foregroundColor(vm.log.isEmpty ? .secondary : .primary)
                }
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .frame(minHeight: 240)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                if vm.isRunning {
                    Button("停止") {
                        vm.cancel()
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    
                    if vm.mode == .server {
                        Button("強制停止伺服器") {
                            vm.forceStopServer()
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(.orange)
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                    }
                } else {
                    Button(vm.mode == .server ? "啟動伺服器" : "開始測試") {
                        vm.start()
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding()
        .animation(.default, value: vm.mode)
    }
    
    // 複製到剪貼板
    private func copyToClipboard(_ text: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #elseif os(iOS)
        UIPasteboard.general.string = text
        #endif
        showCopiedAlert = true
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .phone {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.prepare()
            impactFeedback.impactOccurred()
        }
        #endif
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

// MARK: - 本機 IP 取得工具 (保持原有)
struct LocalIPHelper {
    static func getLocalIPAddress() async -> String {
        return await withCheckedContinuation { continuation in
            let monitor = NWPathMonitor()
            monitor.pathUpdateHandler = { path in
                var result = "無法取得"
                for interface in path.availableInterfaces {
                    if interface.type == .wifi || interface.type == .wiredEthernet {
                        if let ip = getIPAddress(for: interface) {
                            result = ip
                            break
                        }
                    }
                }
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
                    let name = String(cString: (interface?.ifa_name)!)
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
