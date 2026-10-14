# 随想 (Mind to Heart)

用语音记录随想的 iOS app：先用语音说出想法，OpenAI 把它转成文字，再润色成通顺易懂的版本，最后按日期存起来。

## 功能（最小可用版本）

- 🎙 点一下开始录音，再点一下结束
- 📝 OpenAI 语音转文字（`gpt-4o-transcribe`）
- ✨ OpenAI 润色（`gpt-4o-mini`），原文和润色版都会保存，可以来回切换、手动修改、重新润色
- 📅 日期
  - 列表按天分组显示
  - 右上角日历：只看某一天的随想
  - 在某一天的视图里录音，会记到那一天（方便补记）
  - 详情页可以修改日期
- 左滑删除；详情页可以分享或复制

## 运行

需要一台 Mac，装 **Xcode 16 或更新版本**，手机系统 **iOS 17+**。

1. 用 Xcode 打开 `MindToHeart.xcodeproj`
2. 选中项目 → Target `MindToHeart` → **Signing & Capabilities**
   - Team：选你的 Apple ID（没有的话点 Add Account 登录）
   - Bundle Identifier：把 `com.example.MindToHeart` 改成独一无二的，比如 `com.你的名字.MindToHeart`
3. 用数据线连上 iPhone，在顶部选择你的手机，点 ▶︎ 运行
   - 第一次运行时，要在手机上打开「设置 > 通用 > VPN与设备管理」，信任你的开发者证书
   - 手机还需要打开「设置 > 隐私与安全性 > 开发者模式」
4. 打开 app，点左上角齿轮，填入 OpenAI API Key（在 https://platform.openai.com/api-keys 创建）

> 用免费 Apple ID 装的 app 7 天后会过期，到时候重新运行一次就好。付费开发者账号（$99/年）装的可以用一年。

## 代码结构

```
MindToHeart/
├── MindToHeartApp.swift        App 入口，配置 SwiftData
├── Models/Thought.swift        一条随想：日期、原文、润色后文字
├── Services/
│   ├── AudioRecorder.swift     录音（m4a 临时文件，转写完就删掉）
│   └── OpenAIService.swift     调用 OpenAI 转文字和润色，润色提示词也在这里
└── Views/
    ├── ContentView.swift       主页：按日期分组的列表 + 录音按钮
    ├── CalendarSheet.swift     选日期
    ├── ThoughtDetailView.swift 详情：改日期、切换原文/润色、重新润色
    └── SettingsView.swift      API Key 和模型
```

想调整润色风格，改 `OpenAIService.swift` 里的 `polishPrompt` 就行。

## 说明

- API Key 存在本机的 UserDefaults 里，只适合自己用。以后要分发给别人，需要改成通过自己的服务器转发请求。
- 模型名可以在设置里改，以后 OpenAI 出了新模型直接填新名字就能用。
