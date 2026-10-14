# 随想 (Mind to Heart)

个人用的 iOS 随想记录 app：录音 → OpenAI 转文字 → OpenAI 润色 → 按日期保存。和用户交流用中文。

## 技术栈

- SwiftUI + SwiftData，iOS 17+，Xcode 16+（项目用了文件夹同步组，`MindToHeart/` 下新增的文件会自动加入 target，不用改 project.pbxproj）
- 不依赖第三方库
- OpenAI API Key 存在 UserDefaults（只给自己用，暂不需要后端）

## 编译检查

改完代码用模拟器编译确认没有错误（不需要签名）：

```bash
xcodebuild -project MindToHeart.xcodeproj -scheme MindToHeart \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build 2>&1 | grep -E "error:|warning:|BUILD (SUCCEEDED|FAILED)"
```

如果提示找不到 scheme，把 `-scheme MindToHeart` 换成 `-target MindToHeart -sdk iphonesimulator`，并去掉 `-destination` 那一行。

## 代码结构

- `MindToHeart/Models/Thought.swift`：数据模型（date、rawText、polishedText）
- `MindToHeart/Services/AudioRecorder.swift`：录音
- `MindToHeart/Services/OpenAIService.swift`：转文字和润色，润色提示词是 `polishPrompt`
- `MindToHeart/Views/`：主页列表 + 录音按钮、日历筛选、详情、设置
