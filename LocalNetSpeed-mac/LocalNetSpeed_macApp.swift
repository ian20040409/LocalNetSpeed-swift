//
//  LocalNetSpeed_macApp.swift
//  LocalNetSpeed-mac
//
//  Created by 林恩佑 on 2025/8/14.
//

import SwiftUI

@main
struct LocalNetSpeed_macApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(width: 640, height: 940)
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandGroup(after: .help) {
                Button("關於 LocalNetSpeed") {
                    // 可以在這裡添加關於對話框
                    
                }
                .keyboardShortcut("?", modifiers: .command)
            }
        }
    }
}
