//
//  NumberSelectorView.swift
//  LocalNetSpeed
//
//  Created by 林恩佑 on 2025/8/15.
//


import SwiftUI

// 一個可以上下選擇 0-9 數字的 View
struct NumberSelectorView: View {
    @Binding var number: Int
    @FocusState.Binding var focusedField: FocusableField?
    let fieldId: FocusableField

    var body: some View {
        Text(String(format: "%d", number))
            .font(.system(size: 40, weight: .semibold))
            .frame(width: 50, height: 60)
            .background(focusedField == fieldId ? Color.gray.opacity(0.3) : Color.clear)
            .cornerRadius(8)
            .focusable() // 讓這個 View 可以接收焦點
            .focused($focusedField, equals: fieldId)
            // 處理遙控器手勢
            .onMoveCommand { direction in
                if direction == .up {
                    number = (number + 1) % 10 // 向上+1，超過9回到0
                } else if direction == .down {
                    number = (number - 1 + 10) % 10 // 向下-1，小於0回到9
                }
            }
    }
}