# LocalNetSpeed-swift
# LocalNetSpeed (Swift)

本專案示範如何用 Swift 實作一個本地網路速度測試工具，包含：
- 命令列版本 (Server / Client)
- SwiftUI 介面版本 (macOS / iOS)

## 功能
- TCP Socket 傳輸資料測速
- 可設定封包總大小
- 顯示進度
- Gigabit 效能評估 (125 MB/s 理論，100 MB/s 為實務優秀門檻)

## 命令列使用

### 建置
```bash
swift build -c release
```

### 啟動伺服器
```bash
swift run LocalNetSpeed server --port 65432
```

### 啟動客戶端 (傳 100MB)
```bash
swift run LocalNetSpeed client --host 192.168.1.10 --port 65432 --size 100
```

參數說明：
- `--size` 單位：MB
- `--port` 預設 65432

## SwiftUI App
開啟 Xcode -> 選擇本專案 -> 執行目標 LocalNetSpeedApp (macOS 或 iOS)。  
iOS 需在 `Info.plist` 加上：
```xml
<key>NSLocalNetworkUsageDescription</key>
<string>此 App 需要使用區域網路來進行速度測試。</string>
```

## 注意事項
- iOS 上直接建立任意 TCP Listener 需通過本地網路權限，第一次會跳提示。
- 測速結果會受限於：磁碟 I/O、系統調度、記憶體壓力、防火牆、Wi‑Fi/有線品質等。
- 若想更準確，可改用 `dispatch_data`、`sendfile` 或調整 socket buffer。
  
## 待改進方向
- 支援 UDP 測試
- 加入多執行緒/平行連線測試
- 自動探索 (Bonjour)
- 統計多次測試平均值
