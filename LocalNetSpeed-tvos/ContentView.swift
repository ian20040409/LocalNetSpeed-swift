import SwiftUI
import Network

// MARK: - Speed Gauge View (tvOS)
struct SpeedGaugeView: View {
    let speed: Double
    let unit: String
    let maxSpeed: Double
    
    @State private var animatedProgress: Double = 0
    
    private var progress: Double {
        min(speed / maxSpeed, 1.0)
    }
    
    private var gaugeColor: Color {
        switch progress {
        case 0.8...: return .green
        case 0.5..<0.8: return .yellow
        case 0.2..<0.5: return .orange
        default: return .red
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                // Background arc
                Circle()
                    .trim(from: 0.15, to: 0.85)
                    .stroke(
                        Color.secondary.opacity(0.15),
                        style: StrokeStyle(lineWidth: 18, lineCap: .round)
                    )
                    .rotationEffect(.degrees(90))
                
                // Foreground arc
                Circle()
                    .trim(from: 0.15, to: 0.15 + animatedProgress * 0.7)
                    .stroke(
                        gaugeColor,
                        style: StrokeStyle(lineWidth: 18, lineCap: .round)
                    )
                    .rotationEffect(.degrees(90))
                    .shadow(color: gaugeColor.opacity(0.5), radius: 6, x: 0, y: 0)
                
                // Speed text
                VStack(spacing: 4) {
                    Text(String(format: "%.1f", speed))
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                    Text(unit)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 260, height: 260)
        }
        .onAppear {
            withAnimation(.spring(response: 1.2, dampingFraction: 0.7)) {
                animatedProgress = progress
            }
        }
        .onChange(of: speed) { _, _ in
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                animatedProgress = progress
            }
        }
    }
}

// MARK: - Card Style (tvOS)
struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.thinMaterial)
            )
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
}

// MARK: - Content View
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
            VStack(spacing: 28) {
                // Header
                HStack(spacing: 12) {
                    Image(systemName: "network")
                        .font(.system(size: 28))
                        .foregroundColor(.accentColor)
                    Text("區域網路速度測試")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundColor(.primary)
                }
                .padding(.top, 10)
                
                // Local IP Card
                VStack(spacing: 15) {
                    HStack(spacing: 8) {
                        Image(systemName: "wifi")
                            .font(.title3)
                            .foregroundColor(.accentColor)
                        Text("本機 IP 位址")
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                    
                    HStack(spacing: 20) {
                        Text(localIP)
                            .font(.system(.title3, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundColor(localIP == "獲取中..." || localIP == "無法取得" ? .secondary : .green)
                            .padding()
                            .clipShape(RoundedRectangle(cornerRadius: 15))
                        
                        Button {
                            getLocalIPAddress()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.clockwise")
                                Text("重新整理")
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                        .tint(.blue)
                    }
                }
                .cardStyle()

                // Mode Picker
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
                    
                    Picker("單位", selection: $vm.selectedUnit) {
                        ForEach(ContentViewModel.SpeedUnit.allCases) { unit in
                            Text(unit.rawValue).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 600)
                }

                // Client Mode: Server Selection
                if vm.mode == .client {
                    VStack(spacing: 30) {
                        HStack(spacing: 8) {
                            Image(systemName: "link")
                                .foregroundColor(.accentColor)
                            Text("輸入目標伺服器 IP")
                        }
                        
                        VStack(spacing: 20) {
                            HStack {
                                Image(systemName: "server.rack")
                                    .foregroundColor(.secondary)
                                Text("目標 IP: \(vm.manualHost.isEmpty ? "尚未設定" : vm.manualHost)")
                                    .font(.title3)

                                Button {
                                    isShowingIPInputView = true
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "pencil")
                                        Text("編輯")
                                    }
                                }
                                .focused($focusedButton, equals: .manualInput)
                            }
                            .cardStyle()
                            .sheet(isPresented: $isShowingIPInputView) {
                                IPInputView { ipString in
                                    vm.manualHost = ipString
                                    vm.finishManualInput()
                                    isShowingIPInputView = false
                                    vm.start()
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
                        .cardStyle()

                        // Clear button
                        if !vm.getTargetHost().isEmpty {
                            HStack(spacing: 20) {
                                Button {
                                    vm.clearPresetSelection()
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "xmark.circle")
                                        Text("清除輸入")
                                    }
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.large)
                                .focused($focusedButton, equals: .clearSelection)
                            }
                        }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
                
                // Server Status
                if vm.mode == .server && vm.isRunning {
                    VStack(spacing: 15) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(.green)
                                .frame(width: 10, height: 10)
                                .scaleEffect(vm.isRunning ? 1.0 : 0.5)
                                .animation(
                                    .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                                    value: vm.isRunning
                                )
                            Text("伺服器狀態")
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                        
                        VStack(spacing: 20) {
                            // Connection info
                            if localIP != "獲取中..." && localIP != "無法取得" {
                                VStack(spacing: 8) {
                                    Text("伺服器位址")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("\(localIP):\(vm.port)")
                                        .font(.system(.title2, design: .monospaced))
                                        .fontWeight(.bold)
                                        .foregroundColor(.blue)
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(.blue.opacity(0.1))
                                )
                            }
                            
                            // Stats
                            HStack(spacing: 30) {
                                VStack {
                                    Text("埠號")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(vm.port)
                                        .font(.system(.title2, design: .monospaced))
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
                        .cardStyle()
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }

                // Progress
                VStack(spacing: 20) {
                    HStack(spacing: 8) {
                        if vm.isRunning {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text("測試狀態")
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                    
                    Text(vm.progressText)
                        .font(.title3)
                        .foregroundColor(vm.isRunning ? .blue : .secondary)
                        .padding()
                        .frame(minWidth: 400)
                        .background(
                            RoundedRectangle(cornerRadius: 15)
                                .fill(.thinMaterial)
                        )
                }

                // Results
                if let result = vm.result {
                    VStack(spacing: 25) {
                        Text("測試結果")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        VStack(spacing: 20) {
                            let speedVal = vm.selectedUnit.convert(fromMBps: result.speedMBps)
                            let maxSpeed: Double = {
                                switch vm.selectedUnit {
                                case .mbps: return 1000
                                case .gbps: return 1
                                case .mbs: return 125
                                case .kbps: return 1_000_000
                                }
                            }()
                            
                            // Speed Gauge
                            SpeedGaugeView(
                                speed: speedVal,
                                unit: vm.selectedUnit.rawValue,
                                maxSpeed: maxSpeed
                            )
                            
                            // Evaluation
                            Text(result.evaluation.rating)
                                .font(.system(size: 32, weight: .semibold))
                            
                            // Stats
                            VStack(spacing: 15) {
                                HStack(spacing: 40) {
                                    VStack {
                                        Image(systemName: "arrow.up.arrow.down")
                                            .foregroundColor(.accentColor)
                                        Text("傳輸量")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text("\(String(format: "%.2f", Double(result.transferredBytes)/1024/1024)) MB")
                                            .font(.title3)
                                            .fontWeight(.medium)
                                    }
                                    VStack {
                                        Image(systemName: "clock")
                                            .foregroundColor(.accentColor)
                                        Text("耗時")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text("\(String(format: "%.2f", result.duration)) 秒")
                                            .font(.title3)
                                            .fontWeight(.medium)
                                    }
                                    VStack {
                                        Image(systemName: "chart.bar")
                                            .foregroundColor(.accentColor)
                                        Text("達成率")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text("\(String(format: "%.1f", result.evaluation.performancePercent))%")
                                            .font(.title3)
                                            .fontWeight(.medium)
                                    }
                                }
                            }
                        }
                        .cardStyle()
                    }
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
                }

                // Control Buttons
                VStack(spacing: 30) {
                    Button {
                        vm.isRunning ? vm.cancel() : vm.start()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: vm.isRunning ? "stop.circle.fill" : "play.circle.fill")
                            Text(vm.isRunning ? "停止測試" : "開始測試")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .font(.system(size: 24, weight: .semibold))
                    .tint(vm.isRunning ? .red : .blue)
                    .focused($focusedButton, equals: .startStop)
                    
                    // Force stop server
                    if vm.mode == .server && vm.isRunning {
                        Button {
                            vm.forceStopServer()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "xmark.octagon.fill")
                                Text("強制停止伺服器")
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .font(.title3)
                        .tint(.orange)
                        .focused($focusedButton, equals: .forceStop)
                    }
                    
                    // Clear log
                    if !vm.log.isEmpty {
                        Button {
                            vm.clearLog()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "trash")
                                Text("清除記錄")
                            }
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
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: vm.mode)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: vm.isRunning)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: vm.result != nil)
        .onAppear {
            focusedButton = .modeSelection
            getLocalIPAddress()
        }
        .onChange(of: vm.mode) { _, newMode in
            if newMode == .client {
                focusedButton = .manualInput
            } else {
                focusedButton = .startStop
            }
        }
    }
    
    // Helper: icon for mode
    private func icon(for mode: SpeedTestMode) -> String {
        switch mode {
        case .server:
            return "server.rack"
        case .client:
            return "iphone"
        }
    }
    
    // Get local IP
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
