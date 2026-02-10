import SwiftUI
import Network

struct ContentView: View {
    @StateObject private var vm = ContentViewModel()
    @State private var localIP = "獲取中..."
    @State private var showCopiedAlert = false
    @State private var showFastCom = false
    @State private var showLog = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Picker("模式", selection: $vm.mode) {
                            ForEach(SpeedTestMode.allCases) { m in
                                Text(m.rawValue).tag(m)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: .infinity) // Added for full width
                        .disabled(vm.isRunning)
                        
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
                            HStack {
                                TextField("伺服器 IP", text: $vm.host)
                                    .textFieldStyle(.roundedBorder)
                                
                                Button("貼上") {
                                    if let string = UIPasteboard.general.string {
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
                    .padding()
                }
                .navigationTitle("LocalNetSpeed")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        HStack {
                            Button {
                                showLog = true
                            } label: {
                                Label("日誌", systemImage: "doc.text")
                            }
                            
                            Button {
                                showFastCom = true
                            } label: {
                                Label("Fast.com", systemImage: "safari")
                            }
                        }
                    }
                }
                
                Divider()
                
                // 底部按鈕
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
                        .controlSize(.large)
                    }
                }
                .padding()
                .background(Color(uiColor: .systemBackground).opacity(0.8)) // Sticky footer background
            }
        }
        .animation(.default, value: vm.mode)
        .onAppear {
            getLocalIPAddress()
        }
        .alert("已複製", isPresented: $showCopiedAlert) {
            Button("確定") { }
        } message: {
            Text("IP 位址已複製到剪貼板")
        }
        .sheet(isPresented: $showFastCom) {
            FastComView()
        }
        .sheet(isPresented: $showLog) {
            LogView(vm: vm)
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



// MARK: - 本機 IP 取得工具 (保持原有)

