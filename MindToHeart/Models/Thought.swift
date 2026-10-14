import Foundation
import SwiftData

/// 一条随想：语音转写的原文 + AI 润色后的文字。
@Model
final class Thought {
    /// 这条随想归属的日期（可以手动修改，用来补记）
    var date: Date
    var createdAt: Date
    var rawText: String
    var polishedText: String
    /// 带格式的版本（加粗、标题、列表等），为空时按纯文本显示。见 RichText
    var rawRichText: Data?
    var polishedRichText: Data?

    init(date: Date = .now, rawText: String, polishedText: String = "") {
        self.date = date
        self.createdAt = .now
        self.rawText = rawText
        self.polishedText = polishedText
    }

    /// 有润色版本就显示润色版本，否则显示原文
    var displayText: String {
        polishedText.isEmpty ? rawText : polishedText
    }
}
