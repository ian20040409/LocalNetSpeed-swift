//
//  IPInputView.swift
//  LocalNetSpeed
//
//  Created by 林恩佑 on 2025/8/15.
//

import SwiftUI

// 定義可以被聚焦的欄位 (此 enum 保持不變)
enum FocusableField: Hashable {
    case octet1_digit1, octet1_digit2, octet1_digit3
    case octet2_digit1, octet2_digit2, octet2_digit3
    case octet3_digit1, octet3_digit2, octet3_digit3
    case octet4_digit1, octet4_digit2, octet4_digit3
    case doneButton
}

struct IPInputView: View {
    // 預設 IP 狀態變數
    @State private var octet1: [Int] = [1, 9, 2]
    @State private var octet2: [Int] = [1, 6, 8]
    @State private var octet3: [Int] = [0, 0, 1]
    @State private var octet4: [Int] = [0, 0, 1]

    // 用於回傳最終 IP 字串的閉包
    var onDone: (String) -> Void

    @FocusState private var focusedField: FocusableField?

    // *** 新增的輔助函式，用於產生正確格式的 IP 字串 ***
    private func generateCorrectIPString() -> String {
        // 輔助閉包：將 [Int] 陣列轉換為一個整數值
        // 例如：[0, 8, 5] -> 85
        let toInt = { (digits: [Int]) -> Int in
            guard digits.count == 3 else { return 0 }
            let value = (digits[0] * 100) + (digits[1] * 10) + digits[2]
            return min(value, 255) // 確保 IP 每個部分不超過 255
        }
        
        let ipPart1 = toInt(octet1)
        let ipPart2 = toInt(octet2)
        let ipPart3 = toInt(octet3)
        let ipPart4 = toInt(octet4)
        
        return "\(ipPart1).\(ipPart2).\(ipPart3).\(ipPart4)"
    }

    var body: some View {
        VStack(spacing: 40) { // 增加垂直間距
            // *** 新增標題和說明文字 ***
            VStack {
                Text("輸入目標伺服器 IP")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("使用遙控器上下滑動選擇數字，左右移動欄位")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 0) {
                // 第一部分
                OctetInputView(octet: $octet1, focusState: $focusedField, fieldIds: [.octet1_digit1, .octet1_digit2, .octet1_digit3])
                Text(".").font(.system(size: 40, weight: .semibold)).padding(.horizontal, 5)
                // 第二部分
                OctetInputView(octet: $octet2, focusState: $focusedField, fieldIds: [.octet2_digit1, .octet2_digit2, .octet2_digit3])
                Text(".").font(.system(size: 40, weight: .semibold)).padding(.horizontal, 5)
                // 第三部分
                OctetInputView(octet: $octet3, focusState: $focusedField, fieldIds: [.octet3_digit1, .octet3_digit2, .octet3_digit3])
                Text(".").font(.system(size: 40, weight: .semibold)).padding(.horizontal, 5)
                // 第四部分
                OctetInputView(octet: $octet4, focusState: $focusedField, fieldIds: [.octet4_digit1, .octet4_digit2, .octet4_digit3])

                // *** 修改 Button 的行為 ***
                Button("完成") {
                    // 使用新的輔助函式來產生正確格式的 IP 字串
                    onDone(generateCorrectIPString())
                }
                .focused($focusedField, equals: .doneButton)
                .padding(.leading, 40) // 增加與 IP 輸入框的距離
            }
            .onAppear {
                // 畫面出現時，預設焦點在第一個數字上
                focusedField = .octet1_digit1
            }
        }
    }
}

// 組合三個數字滾輪的 View (此 View 保持不變)
struct OctetInputView: View {
    @Binding var octet: [Int]
    @FocusState.Binding var focusState: FocusableField?
    let fieldIds: [FocusableField]

    var body: some View {
        HStack(spacing: 2) {
            if octet.count == 3 && fieldIds.count == 3 {
                NumberSelectorView(number: $octet[0], focusedField: $focusState, fieldId: fieldIds[0])
                NumberSelectorView(number: $octet[1], focusedField: $focusState, fieldId: fieldIds[1])
                NumberSelectorView(number: $octet[2], focusedField: $focusState, fieldId: fieldIds[2])
            }
        }
        .padding(8)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray, lineWidth: 1)
        )
    }
}
