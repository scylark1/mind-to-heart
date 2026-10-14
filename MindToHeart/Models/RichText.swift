import UIKit

/// 带格式的文字（标题、加粗、列表等）：样式定义和存取
enum RichText {
    enum Style {
        case title, heading, body
    }

    /// 项目列表的圆点，直接作为文字存在，纯文本里也能看出列表
    static let bullet = "• "

    static func font(for style: Style) -> UIFont {
        switch style {
        case .title: .systemFont(ofSize: 28, weight: .bold)
        case .heading: .systemFont(ofSize: 22, weight: .semibold)
        case .body: .systemFont(ofSize: 17)
        }
    }

    static var bodyAttributes: [NSAttributedString.Key: Any] {
        [.font: font(for: .body), .foregroundColor: UIColor.label]
    }

    static func plain(_ string: String) -> NSAttributedString {
        NSAttributedString(string: string, attributes: bodyAttributes)
    }

    /// 去掉首尾空白和换行，保留中间的格式
    static func trimmed(_ text: NSAttributedString) -> NSAttributedString {
        let string = text.string as NSString
        let whitespace = CharacterSet.whitespacesAndNewlines
        var start = 0
        var end = string.length
        while start < end, let scalar = Unicode.Scalar(string.character(at: start)), whitespace.contains(scalar) {
            start += 1
        }
        while end > start, let scalar = Unicode.Scalar(string.character(at: end - 1)), whitespace.contains(scalar) {
            end -= 1
        }
        return text.attributedSubstring(from: NSRange(location: start, length: end - start))
    }

    /// 文字颜色不存，显示时统一用 .label，这样深色模式下也看得清
    static func encode(_ text: NSAttributedString) -> Data? {
        let copy = NSMutableAttributedString(attributedString: text)
        copy.removeAttribute(.foregroundColor, range: NSRange(location: 0, length: copy.length))
        return try? NSKeyedArchiver.archivedData(withRootObject: copy, requiringSecureCoding: true)
    }

    /// 解码失败，或者纯文本已经在别处被改过（比如重新润色），就按纯文本显示
    static func decode(_ data: Data?, fallback: String) -> NSAttributedString {
        let classes: [AnyClass] = [
            NSAttributedString.self, NSString.self, NSDictionary.self, NSNumber.self,
            UIFont.self, UIColor.self, NSParagraphStyle.self,
        ]
        guard let data,
              let decoded = (try? NSKeyedUnarchiver.unarchivedObject(ofClasses: classes, from: data)) as? NSAttributedString,
              decoded.string == fallback
        else { return plain(fallback) }
        let copy = NSMutableAttributedString(attributedString: decoded)
        copy.addAttribute(.foregroundColor, value: UIColor.label, range: NSRange(location: 0, length: copy.length))
        return copy
    }
}

extension Thought {
    var rawAttributedText: NSAttributedString {
        get { RichText.decode(rawRichText, fallback: rawText) }
        set {
            rawText = newValue.string
            rawRichText = RichText.encode(newValue)
        }
    }

    var polishedAttributedText: NSAttributedString {
        get { RichText.decode(polishedRichText, fallback: polishedText) }
        set {
            polishedText = newValue.string
            polishedRichText = RichText.encode(newValue)
        }
    }
}

extension UIFont {
    func withTrait(_ trait: UIFontDescriptor.SymbolicTraits, enabled: Bool) -> UIFont {
        var traits = fontDescriptor.symbolicTraits
        if enabled {
            traits.insert(trait)
        } else {
            traits.remove(trait)
        }
        guard let descriptor = fontDescriptor.withSymbolicTraits(traits) else { return self }
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}
