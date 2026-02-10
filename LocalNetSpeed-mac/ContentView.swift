//
//  ContentView.swift
//  LocalNetSpeed-mac
//
//  Created by 林恩佑 on 2025/8/14.
//

import SwiftUI
import Network

struct ContentView: View {
    @StateObject private var vm = ContentViewModel()
    @State private var localIP = "獲取中..."
    @State private var showCopiedAlert = false
    
    @State private var showLog = false
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 標題區域
                    HStack {
                        Image(systemName: "network")
                            .font(.title2)
                            .foregroundColor(.accentColor)
                        Text("LocalNetSpeed")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Spacer()
                        
                        Button {
                            showLog = true
                        } label: {
                            Label("日誌", systemImage: "doc.text")
                        }
                        .buttonStyle(.bordered)
                        .help("顯示日誌")
                    }
                    .padding(.bottom, 8)
                    
                    // 權限提示區域
                    if vm.mode == .server {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("伺服器模式需要網路權限")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                Text("首次使用時 macOS 可能會要求網路存取權限")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding(8)
                        .background(.blue.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    
                    Picker("模式", selection: $vm.mode) {
                        ForEach(SpeedTestMode.allCases) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                    .disabled(vm.isRunning)
                    
                    // 顯示本機 IP
                    HStack {
                        Text("本機 IP:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(localIP)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .textSelection(.enabled) // 可選取複製
                        
                        Spacer()
                        
                        // 複製按鈕
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
                        HStack {
                            TextField("伺服器 IP", text: $vm.host)
                                .textFieldStyle(.roundedBorder)
                            
                            Button("貼上") {
                                if let string = NSPasteboard.general.string(forType: .string) {
                                    vm.host = string
                                }
                            }
                            .buttonStyle(.bordered)
                        }
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
                    .padding(.bottom, 8)

                    // 狀態顯示
                    if vm.isRunning || (!vm.progressText.isEmpty && vm.progressText != "尚未開始") {
                        HStack {
                            if vm.isRunning && vm.mode == .server {
                                // 伺服器運行指示器
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
                    
                    // 測試結果卡片
                    if let r = vm.result {
                        let speedVal = vm.selectedUnit.convert(fromMBps: r.speedMBps)
                        let eval = r.evaluation
                        
                        VStack(spacing: 12) {
                            // 大字速度
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(String(format: "%.1f", speedVal))
                                    .font(.system(size: 48, weight: .bold, design: .rounded))
                                    .foregroundColor(.green)
                                Text(vm.selectedUnit.rawValue)
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                            }
                            
                            // 評級
                            Text(eval.rating)
                                .font(.title3)
                            
                            // 統計數據
                            HStack(spacing: 16) {
                                statBadge(label: "總量", value: String(format: "%.1f MB", Double(r.transferredBytes)/1024/1024))
                                statBadge(label: "耗時", value: String(format: "%.2f 秒", r.duration))
                                statBadge(label: "達成", value: String(format: "%.0f%%", eval.performancePercent))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(16)
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(20)
            }
            
            Divider()
            
            // 測試按鈕 (Sticky Footer)
            HStack(spacing: 12) {
                if vm.isRunning {
                    // 當運行中時顯示停止按鈕
                    Button("停止") {
                        vm.cancel()
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    
                    // 伺服器模式顯示額外的狀態資訊
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
                    // 當未運行時顯示開始按鈕
                    Button(vm.mode == .server ? "啟動伺服器" : "開始測試") {
                        vm.start()
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .controlSize(.large)
                }
            }
            .padding(16)
            .background(.ultraThinMaterial)
        }
        .frame(minWidth: 480, minHeight: 580)
        .animation(.default, value: vm.mode)
        .onAppear {
            getLocalIPAddress()
        }
        .alert("已複製", isPresented: $showCopiedAlert) {
            Button("確定") { }
        } message: {
            Text("IP 位址已複製到剪貼板")
        }
        .sheet(isPresented: $showLog) {
            MacLogView(vm: vm)
                .frame(minWidth: 400, minHeight: 400)
        }
    }
    
    // 複製到剪貼板
    private func copyToClipboard(_ text: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #elseif os(iOS)
        UIPasteboard.general.string = text
        #endif
        
        // 顯示複製成功提示
        showCopiedAlert = true
        
        // 觸覺回饋 (iOS)
        #if os(iOS)
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        #endif
    }
    
    // 獲取本機 IP 位址
    @ViewBuilder
    private func statBadge(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity)
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

// LogView for macOS
struct MacLogView: View {
    @ObservedObject var vm: ContentViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("日誌")
                    .font(.headline)
                Spacer()
                if !vm.log.isEmpty {
                    Button("清除") {
                        vm.clearLog()
                    }
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            
            ScrollView {
                Text(vm.log.isEmpty ? "尚無日誌記錄" : vm.log)
                    .font(.system(.footnote, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .textSelection(.enabled)
            }
            
            Divider()
            
            HStack {
                Spacer()
                Button("關閉") {
                    presentationMode.wrappedValue.dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
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

#Preview {
    ContentView()
}
