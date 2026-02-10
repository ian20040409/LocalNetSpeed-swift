//
//  ContentView.swift
//  LocalNetSpeed-mac
//
//  Created by 林恩佑 on 2025/8/14.
//

import SwiftUI
import Network

// MARK: - Speed Gauge View (macOS)
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
        VStack(spacing: 8) {
            ZStack {
                // Background arc
                Circle()
                    .trim(from: 0.15, to: 0.85)
                    .stroke(
                        Color.secondary.opacity(0.15),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .rotationEffect(.degrees(90))
                
                // Foreground arc
                Circle()
                    .trim(from: 0.15, to: 0.15 + animatedProgress * 0.7)
                    .stroke(
                        gaugeColor,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .rotationEffect(.degrees(90))
                    .shadow(color: gaugeColor.opacity(0.4), radius: 4, x: 0, y: 0)
                
                // Speed text
                VStack(spacing: 2) {
                    Text(String(format: "%.1f", speed))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                    Text(unit)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 160, height: 160)
        }
        .onAppear {
            withAnimation(.spring(response: 1.0, dampingFraction: 0.7)) {
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

// MARK: - Card Modifier (macOS)
struct CardStyle: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    
    func body(content: Content) -> some View {
        content
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .shadow(
                        color: colorScheme == .dark
                            ? Color.white.opacity(0.03)
                            : Color.black.opacity(0.06),
                        radius: 6, x: 0, y: 2
                    )
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
    @State private var localIP = "獲取中..."
    @State private var showCopiedAlert = false
    
    @State private var showLog = false
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
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
                    
                    // Server mode info
                    if vm.mode == .server {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle.fill")
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
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.blue.opacity(0.08))
                        )
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }
                    
                    // Mode Picker with icons
                    HStack(spacing: 0) {
                        ForEach(SpeedTestMode.allCases) { m in
                            Button {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    vm.mode = m
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: m == .server ? "server.rack" : "desktopcomputer")
                                        .font(.subheadline)
                                    Text(m.rawValue)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(vm.mode == m ? Color.accentColor : Color.clear)
                                        .opacity(vm.mode == m ? 1 : 0)
                                )
                                .foregroundColor(vm.mode == m ? .white : .primary)
                            }
                            .buttonStyle(.plain)
                            .disabled(vm.isRunning)
                        }
                    }
                    .padding(4)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.secondary.opacity(0.1))
                    )
                    
                    // Local IP Card
                    HStack(spacing: 10) {
                        Image(systemName: "network")
                            .font(.title3)
                            .foregroundColor(.accentColor)
                            .frame(width: 28)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("本機 IP")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(localIP)
                                .font(.system(.subheadline, design: .monospaced))
                                .fontWeight(.semibold)
                                .textSelection(.enabled)
                        }
                        
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
                        
                        Button {
                            getLocalIPAddress()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                    }
                    .cardStyle()
                    
                    // Client: Server IP
                    if vm.mode == .client {
                        HStack {
                            Image(systemName: "link")
                                .foregroundColor(.secondary)
                            TextField("伺服器 IP", text: $vm.host)
                                .textFieldStyle(.roundedBorder)
                            
                            Button("貼上") {
                                if let string = NSPasteboard.general.string(forType: .string) {
                                    vm.host = string
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    
                    // Port & Size
                    HStack {
                        Image(systemName: "number")
                            .foregroundColor(.secondary)
                        TextField("埠號", text: $vm.port)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 120)
                        if vm.mode == .client {
                            Image(systemName: "doc")
                                .foregroundColor(.secondary)
                            TextField("資料大小 (MB)", text: $vm.sizeMB)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: 140)
                        }
                        Spacer()
                    }
                    
                    // Unit Picker
                    Picker("單位", selection: $vm.selectedUnit) {
                        ForEach(ContentViewModel.SpeedUnit.allCases) { unit in
                            Text(unit.rawValue).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.bottom, 8)

                    // Status Display
                    if vm.isRunning || (!vm.progressText.isEmpty && vm.progressText != "尚未開始") {
                        VStack(alignment: .leading, spacing: 8) {
                            if vm.isRunning && vm.mode == .server {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(.green)
                                        .frame(width: 8, height: 8)
                                        .scaleEffect(vm.isRunning ? 1.0 : 0.5)
                                        .animation(
                                            .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                                            value: vm.isRunning
                                        )
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
                            }
                            
                            // Progress bar for client
                            if vm.isRunning && vm.mode == .client {
                                let percentText = vm.progressText
                                if let range = percentText.range(of: #"[\d.]+(?=%)"#, options: .regularExpression),
                                   let pct = Double(percentText[range]) {
                                    ProgressView(value: pct, total: 100)
                                        .progressViewStyle(.linear)
                                        .tint(.accentColor)
                                        .animation(.easeInOut(duration: 0.3), value: pct)
                                }
                            }
                            
                            Text(vm.progressText)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .cardStyle()
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }
                    
                    // Result Card with Gauge
                    if let r = vm.result {
                        let speedVal = vm.selectedUnit.convert(fromMBps: r.speedMBps)
                        let maxSpeed: Double = {
                            switch vm.selectedUnit {
                            case .mbps: return 1000
                            case .gbps: return 1
                            case .mbs: return 125
                            case .kbps: return 1_000_000
                            }
                        }()
                        
                        VStack(spacing: 16) {
                            SpeedGaugeView(
                                speed: speedVal,
                                unit: vm.selectedUnit.rawValue,
                                maxSpeed: maxSpeed
                            )
                            
                            // Evaluation
                            Text(r.evaluation.rating)
                                .font(.headline)
                            
                            // Stats
                            HStack(spacing: 20) {
                                statBadge(
                                    icon: "arrow.up.arrow.down",
                                    label: "總量",
                                    value: String(format: "%.1f MB", Double(r.transferredBytes)/1024/1024)
                                )
                                
                                Divider()
                                    .frame(height: 30)
                                
                                statBadge(
                                    icon: "clock",
                                    label: "耗時",
                                    value: String(format: "%.2f 秒", r.duration)
                                )
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .cardStyle()
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                    }
                }
                .padding(20)
            }
            
            Divider()
            
            // Bottom Action Buttons
            HStack(spacing: 12) {
                if vm.isRunning {
                    Button {
                        vm.cancel()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "stop.circle.fill")
                            Text("停止")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
                    .controlSize(.large)
                    
                    if vm.mode == .server {
                        Button {
                            vm.forceStopServer()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "xmark.octagon.fill")
                                Text("強制停止伺服器")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(.orange)
                        .font(.caption)
                        .controlSize(.large)
                    }
                } else {
                    Button {
                        vm.start()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: vm.mode == .server ? "play.circle.fill" : "bolt.circle.fill")
                            Text(vm.mode == .server ? "啟動伺服器" : "開始測試")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
            .padding(16)
            .background(.ultraThinMaterial)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: vm.mode)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: vm.isRunning)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: vm.result != nil)
        .onAppear {
            getLocalIPAddress()
        }
        .sheet(isPresented: $showLog) {
            MacLogView(vm: vm)
                .frame(minWidth: 400, minHeight: 400)
        }
        .overlay(alignment: .bottom) {
            if showCopiedAlert {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("IP 位址已複製到剪貼板")
                        .font(.subheadline)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.15), radius: 5, x: 0, y: 2)
                .padding(.bottom, 24)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
    
    // Copy to clipboard
    private func copyToClipboard(_ text: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #elseif os(iOS)
        UIPasteboard.general.string = text
        #endif
        
        withAnimation {
            showCopiedAlert = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showCopiedAlert = false
            }
        }
        
        #if os(iOS)
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        #endif
    }
    
    // Stat Badge
    @ViewBuilder
    private func statBadge(icon: String, label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.accentColor)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity)
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

// LogView for macOS


// MARK: - 本機 IP 取得工具


#Preview {
    ContentView()
}
