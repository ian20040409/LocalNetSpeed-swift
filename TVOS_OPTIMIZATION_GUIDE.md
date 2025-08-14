# tvOS 版本優化指南

## 概述

本文檔說明 LocalNetSpeed Apple TV 版本的優化特性和改進。tvOS 版本專為 10 英尺使用距離和遙控器操作進行了全面優化。

## 主要優化特性

### 1. 使用者介面優化

#### 大型 UI 元素
- **標題字體**: 從 `.largeTitle` 升級到 `.system(size: 60, weight: .bold)`
- **按鈕尺寸**: 主要按鈕為 400x100 像素，確保遙控器易於選擇
- **間距**: 所有元素間距增加到 30-40 像素，提供更好的視覺分離

#### 焦點管理系統
```swift
@FocusState private var focusedButton: FocusableButton?

enum FocusableButton {
    case modeServer, modeClient
    case preset1, preset2, preset3, preset4, preset5, preset6
    case clearSelection
    case startStop, forceStop
    case clearLog
}
```

- 實現完整的焦點導航系統
- 支援 Apple TV 遙控器的方向鍵導航
- 自動設定初始焦點到伺服器模式按鈕

### 2. 簡化的輸入方式

#### 預設 IP 地址選擇
- 提供 6 個常用的預設 IP 地址
- 3x2 網格佈局，適合遙控器導航
- 視覺化選擇狀態（綠色高亮）

```swift
let presetHosts = [
    "192.168.1.100", "192.168.1.101", "192.168.1.102",
    "192.168.0.100", "192.168.0.101", "10.0.0.100"
]
```

#### 移除鍵盤輸入
- 完全移除手動 IP 輸入功能
- 使用預設選項替代，避免虛擬鍵盤的複雜性

### 3. 視覺層次優化

#### 模式選擇
- 大型卡片式設計（280x160 像素）
- 清晰的圖示和說明文字
- 即時視覺回饋

#### 結果顯示
- **速度數字**: 72pt 粗體字型，突出顯示
- **評級**: 36pt 半粗體字型
- **詳細資訊**: 結構化的三欄佈局

### 4. 伺服器狀態監控

#### 即時狀態顯示
- 埠號和連線數的即時更新
- 視覺化的狀態卡片
- 清晰的連線計數器

### 5. 平台特定優化

#### 移除 iOS 特定功能
- 移除觸覺回饋（tvOS 不支援）
- 移除 UIKit 相關的匯入和功能

#### tvOS 特定的 ViewModel 擴展
```swift
// tvOS-specific properties
@Published var selectedPresetHost: String = ""
@Published var showingManualInput = false

func selectPresetHost(_ host: String) {
    selectedPresetHost = host
    self.host = host
}

func clearPresetSelection() {
    selectedPresetHost = ""
    host = ""
}
```

## 技術實現細節

### 1. 焦點系統實現

```swift
.focused($focusedButton, equals: .modeServer)
.buttonStyle(.plain)
```

每個可互動元素都配置了焦點狀態，確保遙控器導航的流暢性。

### 2. 響應式佈局

```swift
ScrollView {
    VStack(spacing: 40) {
        // 內容區域
    }
    .padding(.horizontal, 60)
}
```

使用 ScrollView 確保在不同內容狀態下的可滾動性。

### 3. 視覺回饋系統

- 選中狀態使用不同的背景顏色
- 按鈕狀態變化有清晰的視覺指示
- 進度和狀態資訊突出顯示

## 使用指南

### 1. 基本操作
1. 使用遙控器方向鍵在選項間導航
2. 按下觸控板或選擇按鈕確認選擇
3. 在客戶端模式下，選擇預設 IP 地址
4. 點擊開始測試按鈕執行網路速度測試

### 2. 伺服器模式
- 選擇伺服器模式後直接開始測試
- 監控連線數和埠號狀態
- 可使用強制停止功能

### 3. 客戶端模式
- 從預設 IP 清單中選擇目標伺服器
- 確認選擇後開始測試
- 可清除選擇重新選擇

## 效能考量

### 1. 記憶體優化
- 使用 `@StateObject` 和 `@Published` 進行狀態管理
- 適當的生命週期管理

### 2. 網路效能
- 保持與原版相同的網路測試邏輯
- 1MB 區塊大小的資料傳輸
- 原子操作確保執行緒安全

### 3. UI 效能
- 使用 `LazyVGrid` 進行高效的網格佈局
- 條件性 UI 渲染減少不必要的計算

## 未來改進方向

1. **語音控制**: 整合 Siri Remote 語音功能
2. **自動發現**: 實現區域網路裝置自動發現
3. **歷史記錄**: 添加測試結果歷史追蹤
4. **圖表顯示**: 實現速度趨勢圖表
5. **多語言支援**: 添加英文等其他語言介面

## 相容性

- **最低系統需求**: tvOS 15.0+
- **建議系統**: tvOS 16.0+ 以獲得最佳體驗
- **硬體需求**: Apple TV 4K (第二代) 或更新版本

## 測試建議

1. 在實際 Apple TV 硬體上測試焦點導航
2. 驗證不同網路環境下的效能
3. 測試長時間運行的穩定性
4. 確認與其他平台版本的互操作性