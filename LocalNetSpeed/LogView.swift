import SwiftUI

struct LogView: View {
    @ObservedObject var vm: ContentViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                ScrollView {
                    Text(vm.log.isEmpty ? "尚無日誌記錄" : vm.log)
                        .font(.system(.footnote, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .foregroundColor(vm.log.isEmpty ? .secondary : .primary)
                }
            }
            .navigationTitle("日誌")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
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
            }
        }
    }
}
