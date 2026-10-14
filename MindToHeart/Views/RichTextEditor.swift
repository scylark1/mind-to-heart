import SwiftUI
import UIKit

/// 类似备忘录的带格式编辑器：键盘上方有格式栏（标题、加粗、斜体、下划线、删除线、列表）
struct RichTextEditor: UIViewRepresentable {
    @Binding var text: NSAttributedString
    var placeholder = ""
    var autoFocus = false

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.allowsEditingTextAttributes = true
        textView.backgroundColor = .clear
        textView.font = RichText.font(for: .body)
        textView.textColor = .label
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 16, bottom: 24, right: 16)
        textView.alwaysBounceVertical = true
        textView.keyboardDismissMode = .interactive
        textView.attributedText = text
        textView.typingAttributes = RichText.bodyAttributes
        textView.inputAccessoryView = context.coordinator.makeToolbar()

        let label = context.coordinator.placeholderLabel
        label.text = placeholder
        label.font = RichText.font(for: .body)
        label.textColor = .placeholderText
        label.translatesAutoresizingMaskIntoConstraints = false
        textView.addSubview(label)
        let padding = textView.textContainer.lineFragmentPadding
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: textView.topAnchor, constant: textView.textContainerInset.top),
            label.leadingAnchor.constraint(
                equalTo: textView.leadingAnchor, constant: textView.textContainerInset.left + padding),
        ])
        label.isHidden = text.length > 0

        context.coordinator.textView = textView
        if autoFocus {
            DispatchQueue.main.async { textView.becomeFirstResponder() }
        }
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        context.coordinator.parent = self
        // 只在外部真的改了内容时才覆盖（比如重新润色），避免打字时光标乱跳
        if textView.attributedText.string != text.string
            || (!textView.isFirstResponder && !textView.attributedText.isEqual(to: text)) {
            textView.attributedText = text
            context.coordinator.placeholderLabel.isHidden = text.length > 0
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: RichTextEditor
        weak var textView: UITextView?
        let placeholderLabel = UILabel()
        /// 在标题行按了回车，换行后要把输入样式改回正文
        private var resetToBodyAfterChange = false

        init(parent: RichTextEditor) {
            self.parent = parent
        }

        // MARK: - 格式栏

        func makeToolbar() -> UIToolbar {
            let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: 320, height: 44))
            func item(_ symbol: String, _ action: @escaping () -> Void) -> UIBarButtonItem {
                UIBarButtonItem(image: UIImage(systemName: symbol), primaryAction: UIAction { _ in action() })
            }
            let styleMenu = UIMenu(children: [
                UIAction(title: "标题") { [weak self] _ in self?.applyStyle(.title) },
                UIAction(title: "小标题") { [weak self] _ in self?.applyStyle(.heading) },
                UIAction(title: "正文") { [weak self] _ in self?.applyStyle(.body) },
            ])
            toolbar.items = [
                UIBarButtonItem(image: UIImage(systemName: "textformat.size"), menu: styleMenu),
                item("bold") { [weak self] in self?.toggleTrait(.traitBold) },
                item("italic") { [weak self] in self?.toggleTrait(.traitItalic) },
                item("underline") { [weak self] in self?.toggleLine(.underlineStyle) },
                item("strikethrough") { [weak self] in self?.toggleLine(.strikethroughStyle) },
                item("list.bullet") { [weak self] in self?.toggleBullet() },
                .flexibleSpace(),
                item("keyboard.chevron.compact.down") { [weak self] in self?.textView?.resignFirstResponder() },
            ]
            toolbar.sizeToFit()
            return toolbar
        }

        /// 加粗 / 斜体：选中的文字全都有就去掉，否则全部加上；没选中文字时影响接下来输入的文字
        func toggleTrait(_ trait: UIFontDescriptor.SymbolicTraits) {
            guard let textView else { return }
            // 先确认输入法里还没确认的字，否则直接改格式会把它们弄丢
            textView.unmarkText()
            let range = textView.selectedRange
            let body = RichText.font(for: .body)

            if range.length == 0 {
                let font = textView.typingAttributes[.font] as? UIFont ?? body
                let enabled = !font.fontDescriptor.symbolicTraits.contains(trait)
                textView.typingAttributes[.font] = font.withTrait(trait, enabled: enabled)
                return
            }

            let storage = textView.textStorage
            var allHave = true
            storage.enumerateAttribute(.font, in: range) { value, _, _ in
                let font = value as? UIFont ?? body
                if !font.fontDescriptor.symbolicTraits.contains(trait) { allHave = false }
            }
            storage.beginEditing()
            storage.enumerateAttribute(.font, in: range) { value, subrange, _ in
                let font = value as? UIFont ?? body
                storage.addAttribute(.font, value: font.withTrait(trait, enabled: !allHave), range: subrange)
            }
            storage.endEditing()
            textView.selectedRange = range
            textChanged()
        }

        /// 下划线 / 删除线
        func toggleLine(_ key: NSAttributedString.Key) {
            guard let textView else { return }
            // 先确认输入法里还没确认的字，否则直接改格式会把它们弄丢
            textView.unmarkText()
            let range = textView.selectedRange
            let on = NSUnderlineStyle.single.rawValue

            if range.length == 0 {
                let hasLine = (textView.typingAttributes[key] as? Int ?? 0) != 0
                textView.typingAttributes[key] = hasLine ? nil : on
                return
            }

            let storage = textView.textStorage
            var allHave = true
            storage.enumerateAttribute(key, in: range) { value, _, _ in
                if (value as? Int ?? 0) == 0 { allHave = false }
            }
            if allHave {
                storage.removeAttribute(key, range: range)
            } else {
                storage.addAttribute(key, value: on, range: range)
            }
            textView.selectedRange = range
            textChanged()
        }

        /// 标题 / 小标题 / 正文：作用于光标所在的整段
        func applyStyle(_ style: RichText.Style) {
            guard let textView else { return }
            // 先确认输入法里还没确认的字，否则直接改格式会把它们弄丢
            textView.unmarkText()
            let selection = textView.selectedRange
            let paragraph = (textView.text as NSString).paragraphRange(for: selection)
            let newFont = RichText.font(for: style)

            textView.typingAttributes[.font] = newFont
            guard paragraph.length > 0 else { return }

            let storage = textView.textStorage
            storage.beginEditing()
            storage.enumerateAttribute(.font, in: paragraph) { value, subrange, _ in
                // 保留斜体，粗细跟着样式走
                let italic = (value as? UIFont)?.fontDescriptor.symbolicTraits.contains(.traitItalic) ?? false
                storage.addAttribute(.font, value: newFont.withTrait(.traitItalic, enabled: italic), range: subrange)
            }
            storage.endEditing()
            textView.selectedRange = selection
            textChanged()
        }

        /// 项目列表：选中的段落都有圆点就去掉，否则都加上
        func toggleBullet() {
            guard let textView else { return }
            // 先确认输入法里还没确认的字，否则直接改格式会把它们弄丢
            textView.unmarkText()
            let text = textView.text as NSString
            let selection = textView.selectedRange
            let paragraph = text.paragraphRange(for: selection)
            let bullet = RichText.bullet
            let bulletLength = (bullet as NSString).length

            var lines: [NSRange] = []
            text.enumerateSubstrings(in: paragraph, options: [.byParagraphs, .substringNotRequired]) { _, range, _, _ in
                lines.append(range)
            }
            if lines.isEmpty {
                // 空文档或者最后一个空行
                lines = [NSRange(location: paragraph.location, length: 0)]
            }

            let removing = lines.allSatisfy { text.substring(with: $0).hasPrefix(bullet) }
            var delta = 0
            // 从后往前改，前面的位置不会被影响
            for line in lines.reversed() {
                if removing {
                    replace(NSRange(location: line.location, length: bulletLength), with: "")
                    delta -= bulletLength
                } else if !text.substring(with: line).hasPrefix(bullet) {
                    replace(NSRange(location: line.location, length: 0), with: bullet)
                    delta += bulletLength
                }
            }

            if lines.count == 1 {
                textView.selectedRange = NSRange(
                    location: max(paragraph.location, selection.location + delta), length: selection.length)
            } else {
                textView.selectedRange = NSRange(location: paragraph.location, length: max(0, paragraph.length + delta))
            }
            textChanged()
        }

        private func replace(_ range: NSRange, with string: String) {
            guard let textView,
                  let start = textView.position(from: textView.beginningOfDocument, offset: range.location),
                  let end = textView.position(from: start, offset: range.length),
                  let textRange = textView.textRange(from: start, to: end)
            else { return }
            textView.replace(textRange, withText: string)
        }

        private func textChanged() {
            guard let textView else { return }
            placeholderLabel.isHidden = textView.attributedText.length > 0
            parent.text = NSAttributedString(attributedString: textView.attributedText)
        }

        // MARK: - UITextViewDelegate

        func textViewDidChange(_ textView: UITextView) {
            if resetToBodyAfterChange {
                resetToBodyAfterChange = false
                textView.typingAttributes = RichText.bodyAttributes
            }
            textChanged()
        }

        /// 回车：列表自动续上圆点，空的列表项结束列表；标题之后的新行回到正文
        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            guard text == "\n" else { return true }

            let font = textView.typingAttributes[.font] as? UIFont
            if let font, font.pointSize > RichText.font(for: .body).pointSize {
                resetToBodyAfterChange = true
            }
            // 输入法还有没确认的字（比如拼音）时交给系统处理，不然会把这些字替换掉
            guard textView.markedTextRange == nil else { return true }

            let string = textView.text as NSString
            let lineRange = string.paragraphRange(for: NSRange(location: range.location, length: 0))
            let line = string.substring(with: lineRange).trimmingCharacters(in: .newlines)
            let bullet = RichText.bullet

            if line.hasPrefix(bullet) {
                if line == bullet {
                    replace(NSRange(location: lineRange.location, length: (bullet as NSString).length), with: "")
                } else {
                    replace(range, with: "\n" + bullet)
                }
                resetToBodyAfterChange = false
                textChanged()
                return false
            }
            return true
        }
    }
}
