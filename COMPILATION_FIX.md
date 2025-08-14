# 編譯錯誤修復

## 問題描述
```
Cannot find 'UIImpactFeedbackGenerator' in scope
Cannot infer contextual base in reference to member 'medium'
```

## 原因
`UIImpactFeedbackGenerator` 是 UIKit 框架的一部分，但 `ContentViewModel.swift` 檔案中沒有匯入 UIKit。

## 解決方案
在 `LocalNetSpeed/ContentViewModel.swift` 檔案頂部新增條件匯入：

```swift
import Foundation
import Combine

#if os(iOS)
import UIKit
#endif
```

## 說明
- 使用 `#if os(iOS)` 條件編譯確保只在 iOS 平台匯入 UIKit
- 這樣可以避免在 macOS 或其他平台上出現不必要的依賴
- 觸覺回饋功能只在 iOS 上可用，因此這種條件匯入是最佳做法

## 驗證
修復後，以下程式碼應該可以正常編譯：
```swift
#if os(iOS)
let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
impactFeedback.impactOccurred()
#endif
```

✅ **問題已解決** - iOS 版本現在應該可以正常編譯和執行觸覺回饋功能。