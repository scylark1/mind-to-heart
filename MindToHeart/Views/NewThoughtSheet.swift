import SwiftUI

/// 手动打字添加一条随想
struct NewThoughtSheet: View {
    /// 保存时回调：文字、照片、日期、是否润色
    var onSave: (_ text: NSAttributedString, _ photos: [Data], _ date: Date, _ polish: Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var polish = false
    @State private var text = NSAttributedString()
    @State private var photos: [PhotoItem] = []
    @State private var date: Date

    private let hasAPIKey = OpenAIService.fromSettings().hasAPIKey

    init(date: Date, onSave: @escaping (_ text: NSAttributedString, _ photos: [Data], _ date: Date, _ polish: Bool) -> Void) {
        _date = State(initialValue: date)
        self.onSave = onSave
    }

    private var trimmedText: NSAttributedString {
        RichText.trimmed(text)
    }

    /// 只有照片没有文字也可以保存
    private var isEmpty: Bool {
        trimmedText.length == 0 && photos.isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    DatePicker("日期", selection: $date)
                        .labelsHidden()
                    Spacer()
                    PhotoAddButton { added in
                        photos += added.map { PhotoItem(id: UUID(), data: $0) }
                    }
                    // 只显示图标，打开时高亮；一排放日期、时间、相机已经很满了
                    Toggle(isOn: hasAPIKey ? $polish : .constant(false)) {
                        Label("AI 润色", systemImage: "wand.and.stars")
                            .labelStyle(.iconOnly)
                            .font(.title3)
                    }
                    .toggleStyle(.button)
                    .disabled(!hasAPIKey)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)

                if !photos.isEmpty {
                    PhotoStrip(photos: photos) { id in
                        photos.removeAll { $0.id == id }
                    }
                }

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
                        onSave(trimmedText, photos.map(\.data), date, polish && hasAPIKey)
                        dismiss()
                    }
                    .disabled(isEmpty)
                }
            }
        }
        .interactiveDismissDisabled(!isEmpty)
    }
}
