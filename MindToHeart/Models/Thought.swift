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
    @Relationship(deleteRule: .cascade, inverse: \ThoughtPhoto.thought)
    var photos: [ThoughtPhoto]? = []

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

    /// 按添加顺序排列的照片
    var sortedPhotos: [ThoughtPhoto] {
        (photos ?? []).sorted { $0.createdAt < $1.createdAt }
    }
}
