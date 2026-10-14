import SwiftUI

/// 手动打字添加一条随想
struct NewThoughtSheet: View {
    /// 保存时回调：文字、日期、是否润色
    var onSave: (_ text: String, _ date: Date, _ polish: Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var polish = false
    @State private var text = ""
    @State private var date: Date
    @FocusState private var editorFocused: Bool

    private let hasAPIKey = OpenAIService.fromSettings().hasAPIKey

    init(date: Date, onSave: @escaping (_ text: String, _ date: Date, _ polish: Bool) -> Void) {
        _date = State(initialValue: date)
        self.onSave = onSave
    }

    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $text)
                        .frame(minHeight: 220)
                        .focused($editorFocused)
                }

                Section {
                    DatePicker("日期", selection: $date)
                    Toggle("用 AI 润色", isOn: hasAPIKey ? $polish : .constant(false))
                        .disabled(!hasAPIKey)
                } footer: {
                    if !hasAPIKey {
                        Text("在「设置」里填写 OpenAI API Key 后可以润色")
                    }
                }
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
                    .disabled(trimmedText.isEmpty)
                }
            }
            .onAppear { editorFocused = true }
        }
        .interactiveDismissDisabled(!trimmedText.isEmpty)
    }
}
