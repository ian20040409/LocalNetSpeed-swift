# macOS 權限設定指南

## 問題描述
如果您在執行 LocalNetSpeed Mac 版本時遇到以下錯誤：
```
nw_listener_socket_inbox_create_socket bind(4, ::.65432) tcp, local: ::.65432, definite, attribution: developer, server failed [1: Operation not permitted]
```

這表示 macOS 的沙盒安全機制阻止了 App 建立網路連線。

## 解決方案

### 1. 確認 Xcode 專案設定
1. 在 Xcode 中開啟 `LocalNetSpeed.xcodeproj`
2. 選擇 `LocalNetSpeed-mac` target
3. 前往 "Signing & Capabilities" 標籤
4. 確認已加入以下 Capabilities：
   - **App Sandbox** (已啟用)
   - **Outgoing Connections (Client)** (已勾選)
   - **Incoming Connections (Server)** (已勾選)

### 2. 檢查 Entitlements 檔案
確認 `LocalNetSpeed-mac.entitlements` 檔案包含：
```xml
<key>com.apple.security.network.server</key>
<true/>
<key>com.apple.security.network.client</key>
<true/>
```

### 3. 系統設定
1. 開啟「系統偏好設定」→「安全性與隱私權」→「防火牆」
2. 點擊「防火牆選項」
3. 確認 LocalNetSpeed 被允許接收連入連線

### 4. 替代方案
如果仍有問題，可以嘗試：
- 使用不同的埠號（建議 8080, 9090, 12345）
- 暫時關閉防火牆進行測試
- 使用 `sudo` 權限執行（僅限開發測試）

### 5. 開發者注意事項
- 確保 App 已正確簽署
- 在發布版本中，使用有效的開發者憑證
- 考慮申請網路權限的使用說明

## 測試建議
1. 先嘗試客戶端模式連線到其他裝置
2. 再測試伺服器模式
3. 使用較高的埠號（避免系統保留埠號）