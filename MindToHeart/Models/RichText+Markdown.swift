import UIKit

/// 润色时用 Markdown 和 AI 交换格式：发送前把格式转成 Markdown，收到后再转回来。
/// 只支持编辑器里有的格式：# 标题、## 小标题、**加粗**、*斜体*、~~删除线~~、<u>下划线</u>、- 列表
extension RichText {
    private struct Marker {
        let open: String
        let close: String
        let apply: (inout InlineStyle) -> Void
    }

    private struct InlineStyle {
        var bold = false
        var italic = false
        var strikethrough = false
        var underline = false
    }

    // 顺序有讲究：** 要在 * 之前匹配
    private static let markers: [Marker] = [
        Marker(open: "**", close: "**") { $0.bold.toggle() },
        Marker(open: "~~", close: "~~") { $0.strikethrough.toggle() },
        Marker(open: "<u>", close: "</u>") { $0.underline.toggle() },
        Marker(open: "*", close: "*") { $0.italic.toggle() },
    ]

    // MARK: - 带格式文字 → Markdown

    static func markdown(from text: NSAttributedString) -> String {
        let string = text.string as NSString
        var lines: [String] = []
        string.enumerateSubstrings(
            in: NSRange(location: 0, length: string.length), options: [.byParagraphs, .substringNotRequired]
        ) { _, range, _, _ in
            lines.append(markdownLine(from: text.attributedSubstring(from: range)))
        }
        // 结尾的空行 enumerate 不会给出来
        if string.hasSuffix("\n") { lines.append("") }
        return lines.joined(separator: "\n")
    }

    private static func markdownLine(from line: NSAttributedString) -> String {
        guard line.length > 0 else { return "" }
        let style = paragraphStyle(of: line)
        var prefix = ""
        var body = line
        switch style {
        case .title: prefix = "# "
        case .heading: prefix = "## "
        case .body:
            if line.string.hasPrefix(bullet) {
                prefix = "- "
                body = line.attributedSubstring(
                    from: NSRange(location: (bullet as NSString).length, length: line.length - (bullet as NSString).length))
            }
        }

        var result = prefix
        body.enumerateAttributes(in: NSRange(location: 0, length: body.length)) { attributes, range, _ in
            let run = (body.string as NSString).substring(with: range)
            let traits = (attributes[.font] as? UIFont)?.fontDescriptor.symbolicTraits ?? []
            var open = ""
            var close = ""
            // 标题本身就是粗体，不再额外标 **
            if traits.contains(.traitBold), style == .body { open += "**"; close = "**" + close }
            if traits.contains(.traitItalic) { open += "*"; close = "*" + close }
            if (attributes[.strikethroughStyle] as? Int ?? 0) != 0 { open += "~~"; close = "~~" + close }
            if (attributes[.underlineStyle] as? Int ?? 0) != 0 { open += "<u>"; close = "</u>" + close }
            result += wrap(run, open: open, close: close)
        }
        return result
    }

    /// 标记要紧贴文字，首尾的空格放到标记外面（"**今天 **" 不是合法的 Markdown）
    private static func wrap(_ run: String, open: String, close: String) -> String {
        guard !open.isEmpty else { return run }
        let core = run.trimmingCharacters(in: .whitespaces)
        guard !core.isEmpty else { return run }
        let leading = run.prefix(while: { $0 == " " || $0 == "\t" })
        let trailing = String(run.reversed().prefix(while: { $0 == " " || $0 == "\t" }))
        return leading + open + core + close + trailing
    }

    private static func paragraphStyle(of line: NSAttributedString) -> Style {
        let size = (line.attribute(.font, at: 0, effectiveRange: nil) as? UIFont)?.pointSize ?? 17
        if size >= font(for: .title).pointSize { return .title }
        if size >= font(for: .heading).pointSize { return .heading }
        return .body
    }

    // MARK: - Markdown → 带格式文字

    static func attributed(fromMarkdown markdown: String) -> NSAttributedString {
        var lines = markdown.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: "\n")
        // 模型偶尔会把结果包在 ``` 代码块里
        if lines.first?.hasPrefix("```") == true { lines.removeFirst() }
        if lines.last?.hasPrefix("```") == true { lines.removeLast() }

        let result = NSMutableAttributedString()
        for (index, rawLine) in lines.enumerated() {
            if index > 0 { result.append(NSAttributedString(string: "\n", attributes: bodyAttributes)) }

            var line = rawLine
            var style = Style.body
            var linePrefix = ""
            if line.hasPrefix("# ") {
                style = .title
                line.removeFirst(2)
            } else if let range = line.range(of: #"^#{2,6} "#, options: .regularExpression) {
                style = .heading
                line.removeSubrange(range)
            } else if let range = line.range(of: #"^\s*[-*+] "#, options: .regularExpression) {
                linePrefix = bullet
                line.removeSubrange(range)
            }

            if !linePrefix.isEmpty {
                result.append(NSAttributedString(string: linePrefix, attributes: bodyAttributes))
            }
            result.append(inlineAttributed(line, style: style))
        }
        return result
    }

    /// 解析一行里的 ** * ~~ <u>：只有后面找得到配对的结束标记才当作格式，否则按原样保留
    private static func inlineAttributed(_ line: String, style: Style) -> NSAttributedString {
        let result = NSMutableAttributedString()
        var current = InlineStyle()
        var openMarkers: [String] = []
        var buffer = ""
        var index = line.startIndex

        func flush() {
            guard !buffer.isEmpty else { return }
            var font = RichText.font(for: style)
            if current.bold { font = font.withTrait(.traitBold, enabled: true) }
            if current.italic { font = font.withTrait(.traitItalic, enabled: true) }
            var attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.label]
            if current.strikethrough { attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue }
            if current.underline { attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue }
            result.append(NSAttributedString(string: buffer, attributes: attributes))
            buffer = ""
        }

        scan: while index < line.endIndex {
            let rest = line[index...]
            for marker in markers {
                if let last = openMarkers.last, last == marker.open, rest.hasPrefix(marker.close) {
                    flush()
                    marker.apply(&current)
                    openMarkers.removeLast()
                    index = line.index(index, offsetBy: marker.close.count)
                    continue scan
                }
                if rest.hasPrefix(marker.open),
                   hasCloser(marker, in: rest.dropFirst(marker.open.count)) {
                    flush()
                    marker.apply(&current)
                    openMarkers.append(marker.open)
                    index = line.index(index, offsetBy: marker.open.count)
                    continue scan
                }
            }
            buffer.append(line[index])
            index = line.index(after: index)
        }
        flush()
        return result
    }

    /// 斜体的 * 只认单独的星号（或 *** 里的那一个），不把 ** 拆开用，免得「5*3 元，**重点**」被误判
    private static func hasCloser(_ marker: Marker, in rest: Substring) -> Bool {
        guard marker.close == "*" else { return rest.contains(marker.close) }
        var run = 0
        for character in rest + " " {
            if character == "*" {
                run += 1
            } else {
                if run == 1 || run == 3 { return true }
                run = 0
            }
        }
        return false
    }
}

extension OpenAIService {
    /// 带格式润色：以 Markdown 发给 AI，再把结果转回带格式文字
    func polish(_ text: NSAttributedString) async throws -> NSAttributedString {
        let polished = try await polish(RichText.markdown(from: text))
        return RichText.attributed(fromMarkdown: polished)
    }
}
