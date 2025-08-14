import SwiftUI

struct ContentView: View {
    @StateObject private var vm = ContentViewModel()
    
    var body: some View {
        VStack(spacing: 30) {
            Text("網路速度測試")
                .font(.largeTitle)
                .padding()
            
            // 簡化的模式選擇
            Picker("模式", selection: $vm.mode) {
                ForEach(SpeedTestMode.allCases) { m in
                    Text(m.rawValue).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 600)
            
            // 預設 IP 選項，減少手動輸入
            if vm.mode == .client {
                VStack {
                    Text("選擇伺服器或手動輸入")
                        .font(.headline)
                    
                    HStack {
                        Button("192.168.1.100") {
                            vm.host = "192.168.1.100"
                        }
                        Button("192.168.1.101") {
                            vm.host = "192.168.1.101"
                        }
                        Button("手動輸入") {
                            // 觸發手動輸入
                        }
                    }
                    .buttonStyle(.bordered)
                    
                    if !vm.host.isEmpty {
                        Text("目標: \(vm.host)")
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // 結果顯示
            if let r = vm.result {
                VStack {
                    Text("測試完成")
                        .font(.title2)
                    Text("\(String(format: "%.2f", r.speedMBps)) MB/s")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.green)
                    Text(r.evaluation.rating)
                        .font(.title3)
                }
                .padding()
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20))
            }
            
            Spacer()
            
            // 大按鈕適合遙控器
            Button(vm.isRunning ? "停止測試" : "開始測試") {
                vm.isRunning ? vm.cancel() : vm.start()
            }
            .font(.title2)
            .frame(width: 300, height: 80)
            .background(vm.isRunning ? .red : .blue)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .padding(50)
    }
}
