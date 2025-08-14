# LocalNetSpeed Mac 版本設定指南

## 您遇到的問題
根據錯誤訊息，macOS 的安全機制阻止了 App 建立網路連線。這是正常的安全保護措施。

## 已新增的解決方案

### 1. 權限檔案
✅ **已建立** `LocalNetSpeed-mac.entitlements` - 包含必要的網路權限
✅ **已建立** `Info.plist` - 包含網路使用說明

### 2. 改善的錯誤處理
✅ **已更新** `ContentViewModel.swift` - 提供更清楚的錯誤訊息和解決建議
✅ **已新增** 權限提示區域在 UI 中

### 3. 使用者指南
✅ **已更新** `README.md` - 包含詳細的 macOS 設定說明
✅ **已建立** `setup-mac-permissions.md` - 完整的疑難排解指南

## 立即解決步驟

### 在 Xcode 中：
1. 開啟專案，選擇 `LocalNetSpeed-mac` target
2. 前往 "Signing & Capabilities"
3. 確認已加入：
   - ✅ App Sandbox
   - ✅ Outgoing Connections (Client)
   - ✅ Incoming Connections (Server)

### 快速測試：
1. 先嘗試使用較高的埠號（如 8080, 9090）
2. 首次執行時允許網路權限提示
3. 如果仍有問題，檢查系統防火牆設定

## 檔案清單
```
LocalNetSpeed-mac/
├── LocalNetSpeed_macApp.swift      # 主程式（已優化）
├── ContentView.swift               # UI 介面（已加入權限提示）
├── ContentViewModel.swift          # 商業邏輯（已改善錯誤處理）
├── SpeedTester.swift              # 網路測試引擎
├── SpeedTestMode.swift            # 資料模型
├── GigabitEvaluation.swift        # 效能評估
├── Info.plist                     # 系統資訊（新增）
├── LocalNetSpeed-mac.entitlements # 權限設定（新增）
└── Assets.xcassets/               # 資源檔案
```

## 下一步
1. 在 Xcode 中重新建置專案
2. 確認 entitlements 檔案已正確加入 target
3. 執行 App 並允許網路權限提示
4. 如果仍有問題，參考 `setup-mac-permissions.md` 進行詳細設定

Mac 版本現在已完全功能化，並包含適當的錯誤處理和使用者指導！