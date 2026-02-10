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
                Circle()
                    .trim(from: 0.15, to: 0.85)
                    .stroke(
                        Color.secondary.opacity(0.15),
                        style: StrokeStyle(lineWidth: 18, lineCap: .round)
                    )
                    .rotationEffect(.degrees(90))
                
                Circle()
                    .trim(from: 0.15, to: 0.15 + animatedProgress * 0.7)
                    .stroke(
                        gaugeColor,
                        style: StrokeStyle(lineWidth: 18, lineCap: .round)
                    )
                    .rotationEffect(.degrees(90))
                    .shadow(color: gaugeColor.opacity(0.5), radius: 6, x: 0, y: 0)
                
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
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
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
    @State private var showResult = false

    enum FocusableButton {
        case modeSelection
        case manualInput, clearSelection
        case startStop, forceStop
        case clearLog, refresh
    }

    var body: some View {
        VStack(spacing: 16) {
            // Row 1: Header + IP (compact)
            HStack {
                Image(systemName: "network")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                Text("區域網路速度測試")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Image(systemName: "wifi")
                    .foregroundColor(.accentColor)
                Text(localIP)
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(localIP == "獲取中..." || localIP == "無法取得" ? .secondary : .green)
                
                Button {
                    getLocalIPAddress()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .focused($focusedButton, equals: .refresh)
            }
            .padding(.horizontal, 60)
            
            // Row 2: Mode + Unit pickers (side by side)
            HStack(spacing: 30) {
                Picker("模式", selection: $vm.mode) {
                    ForEach(SpeedTestMode.allCases) { mode in
                        Label(mode.rawValue, systemImage: icon(for: mode))
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .focused($focusedButton, equals: .modeSelection)
                
                Picker("單位", selection: $vm.selectedUnit) {
                    ForEach(ContentViewModel.SpeedUnit.allCases) { unit in
                        Text(unit.rawValue).tag(unit)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(.horizontal, 60)
            
            // Row 3: Client IP input (only in client mode)
            if vm.mode == .client {
                HStack(spacing: 16) {
                    Image(systemName: "server.rack")
                        .foregroundColor(.secondary)
                    Text("目標 IP:")
                        .foregroundColor(.secondary)
                    Text(vm.manualHost.isEmpty ? "尚未設定" : vm.manualHost)
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.medium)
                    
                    Button {
                        isShowingIPInputView = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "pencil")
                            Text("編輯")
                        }
                    }
                    .focused($focusedButton, equals: .manualInput)
                    
                    if !vm.getTargetHost().isEmpty {
                        Button {
                            vm.clearPresetSelection()
                        } label: {
                            Image(systemName: "xmark.circle")
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                        .focused($focusedButton, equals: .clearSelection)
                    }
                }
                .padding(.horizontal, 60)
                .transition(.opacity.combined(with: .move(edge: .top)))
                .sheet(isPresented: $isShowingIPInputView) {
                    IPInputView { ipString in
                        vm.manualHost = ipString
                        vm.finishManualInput()
                        isShowingIPInputView = false
                        vm.start()
                    }
                }
            }
            
            // Row 4: Status bar
            HStack(spacing: 16) {
                // Server status indicator
                if vm.mode == .server && vm.isRunning {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(.green)
                            .frame(width: 10, height: 10)
                            .scaleEffect(vm.isRunning ? 1.0 : 0.5)
                            .animation(
                                .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                                value: vm.isRunning
                            )
                        Text("運行中")
                            .font(.callout)
                            .foregroundColor(.green)
                        
                        if localIP != "獲取中..." && localIP != "無法取得" {
                            Text("\(localIP):\(vm.port)")
                                .font(.system(.callout, design: .monospaced))
                                .foregroundColor(.blue)
                        }
                        
                        Text("· 連線 \(vm.serverConnectionCount)")
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                if vm.isRunning {
                    ProgressView()
                        .controlSize(.small)
                }
                
                Text(vm.progressText)
                    .font(.body)
                    .foregroundColor(vm.isRunning ? .blue : .secondary)
                
                if !(vm.mode == .server && vm.isRunning) {
                    Spacer()
                }
            }
            .padding(.horizontal, 20)
            .cardStyle()
            .padding(.horizontal, 60)
            
            Spacer()
            
            // Row 5: Action buttons (bottom, horizontal)
            HStack(spacing: 20) {
                if vm.isRunning {
                    Button {
                        vm.cancel()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "stop.circle.fill")
                            Text(vm.mode == .server ? "停止伺服器" : "停止測試")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .focused($focusedButton, equals: .startStop)
                    
                    if vm.mode == .server {
                        Button {
                            vm.forceStopServer()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "xmark.octagon.fill")
                                Text("強制停止")
                            }
                        }
                        .buttonStyle(.bordered)
                        .tint(.orange)
                        .focused($focusedButton, equals: .forceStop)
                    }
                } else {
                    Button {
                        vm.start()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: vm.mode == .server ? "play.circle.fill" : "bolt.circle.fill")
                            Text(vm.mode == .server ? "啟動伺服器" : "開始測試")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .focused($focusedButton, equals: .startStop)
                }
                
                if !vm.log.isEmpty {
                    Button {
                        vm.clearLog()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                            Text("清除記錄")
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(.gray)
                    .focused($focusedButton, equals: .clearLog)
                }
            }
            .padding(.bottom, 20)
        }
        .padding(.vertical, 30)
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
        .onChange(of: vm.result) { _, newVal in
            if newVal != nil {
                showResult = true
            }
        }
        .sheet(isPresented: $showResult) {
            if let result = vm.result {
                TVResultView(result: result, unit: vm.selectedUnit)
            }
        }
    }
    
    private func icon(for mode: SpeedTestMode) -> String {
        switch mode {
        case .server: return "server.rack"
        case .client: return "iphone"
        }
    }
    
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
