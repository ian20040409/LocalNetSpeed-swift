import SwiftUI

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
