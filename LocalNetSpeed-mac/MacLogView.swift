import SwiftUI

struct MacLogView: View {
    @ObservedObject var vm: ContentViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "doc.text")
                    .foregroundColor(.accentColor)
                Text("日誌")
                    .font(.headline)
                Spacer()
                if !vm.log.isEmpty {
                    Button {
                        vm.clearLog()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                                .font(.caption)
                            Text("清除")
                        }
                    }
                    .foregroundColor(.red)
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            
            Divider()
            
            // Log content
            ScrollView {
                Text(vm.log.isEmpty ? "尚無日誌記錄" : vm.log)
                    .font(.system(.footnote, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .textSelection(.enabled)
                    .foregroundColor(vm.log.isEmpty ? .secondary : .primary)
            }
            
            Divider()
            
            // Footer
            HStack {
                if !vm.log.isEmpty {
                    Text("\(vm.log.components(separatedBy: "\n").count) 行")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
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
