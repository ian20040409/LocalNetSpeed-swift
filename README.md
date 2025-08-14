# LocalNetSpeed (Swift)

本專案示範如何用 Swift 實作一個本地網路速度測試工具，包含：
- 命令列版本 (Server / Client)
- SwiftUI 介面版本 (iOS / macOS / tvOS)

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
開啟 Xcode -> 選擇本專案 -> 執行目標：
- **LocalNetSpeed**: iOS 版本
- **LocalNetSpeed-mac**: macOS 版本  
- **LocalNetSpeed-tvos**: tvOS 版本

iOS 需在 `Info.plist` 加上：
```xml
<key>NSLocalNetworkUsageDescription</key>
<string>此 App 需要使用區域網路來進行速度測試。</string>
```

## 平台特色
### iOS 版本
- 觸控友善的介面設計
- 支援觸覺回饋
- 自動適應不同螢幕尺寸

### macOS 版本  
- 原生 Mac 介面設計
- 支援鍵盤快捷鍵
- 可調整視窗大小
- 整合系統剪貼板

### tvOS 版本
- 適合電視螢幕的大字體設計
- 遙控器導航支援

## 注意事項

### 網路權限
- **iOS**: 直接建立 TCP Listener 需通過本地網路權限，第一次會跳提示。
- **macOS**: 需要網路權限，建議的解決方案：
  1. 在 Xcode 中確保已加入 `LocalNetSpeed-mac.entitlements` 檔案
  2. 首次執行時允許網路存取權限提示
  3. 如遇到權限問題，可在「系統偏好設定 > 安全性與隱私權 > 防火牆」中允許 App
  4. 或嘗試使用不同的埠號（如 8080, 9090）

### 效能考量
- 測速結果會受限於：磁碟 I/O、系統調度、記憶體壓力、防火牆、Wi‑Fi/有線品質等。
- 若想更準確，可改用 `dispatch_data`、`sendfile` 或調整 socket buffer。

### 疑難排解
如果遇到 "Operation not permitted" 錯誤：
1. 確認 App 已正確簽署並包含網路權限
2. 嘗試使用較高的埠號（1024 以上）
3. 檢查系統防火牆設定
4. 重新啟動 App 並允許網路權限提示
  
## 待改進方向
- 支援 UDP 測試
- 加入多執行緒/平行連線測試
- 自動探索 (Bonjour)
- 統計多次測試平均值
