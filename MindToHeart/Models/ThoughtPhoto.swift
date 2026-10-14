import Foundation
import SwiftData

/// 随想里的一张照片。图片数据存在 SwiftData 的外部文件里，不占数据库本身
@Model
final class ThoughtPhoto {
    @Attribute(.externalStorage) var data: Data
    var createdAt: Date
    var thought: Thought?

    init(data: Data) {
        self.data = data
        self.createdAt = .now
    }
}
