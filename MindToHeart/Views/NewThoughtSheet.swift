import SwiftUI

/// 手动打字添加一条随想
struct NewThoughtSheet: View {
    /// 保存时回调：文字、日期、是否润色
    var onSave: (_ text: NSAttributedString, _ date: Date, _ polish: Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var polish = false
    @State private var text = NSAttributedString()
    @State private var date: Date

    private let hasAPIKey = OpenAIService.fromSettings().hasAPIKey

    init(date: Date, onSave: @escaping (_ text: NSAttributedString, _ date: Date, _ polish: Bool) -> Void) {
        _date = State(initialValue: date)
        self.onSave = onSave
    }

    private var trimmedText: NSAttributedString {
        RichText.trimmed(text)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    DatePicker("日期", selection: $date)
                        .labelsHidden()
                    Spacer()
                    Toggle(isOn: hasAPIKey ? $polish : .constant(false)) {
                        Label("AI 润色", systemImage: "wand.and.stars")
                    }
                    .toggleStyle(.button)
                    .fixedSize()
                    .disabled(!hasAPIKey)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)

                RichTextEditor(text: $text, placeholder: "写下你的想法…", autoFocus: true)
            }
            .navigationTitle("写下想法")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave(trimmedText, date, polish && hasAPIKey)
                        dismiss()
                    }
                    .disabled(trimmedText.length == 0)
                }
            }
        }
        .interactiveDismissDisabled(trimmedText.length > 0)
    }
}
