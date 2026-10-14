import SwiftUI
import SwiftData

struct ThoughtDetailView: View {
    @Bindable var thought: Thought
    @State private var showOriginal = false
    @State private var isPolishing = false
    @State private var errorMessage: String?

    private var hasPolished: Bool {
        !thought.polishedText.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                DatePicker("日期", selection: $thought.date)
                    .labelsHidden()

                if hasPolished {
                    Picker("版本", selection: $showOriginal) {
                        Text("润色后").tag(false)
                        Text("原文").tag(true)
                    }
                    .pickerStyle(.segmented)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)

            if showOriginal || !hasPolished {
                RichTextEditor(text: $thought.rawAttributedText)
            } else {
                RichTextEditor(text: $thought.polishedAttributedText)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    Task { await polish() }
                } label: {
                    if isPolishing {
                        ProgressView()
                    } else {
                        Label(hasPolished ? "根据原文重新润色" : "润色", systemImage: "wand.and.stars")
                    }
                }
                .disabled(isPolishing)

                ShareLink(item: showOriginal ? thought.rawText : thought.displayText) {
                    Label("分享 / 复制", systemImage: "square.and.arrow.up")
                }
            }
        }
        .alert("出错了", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("好", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func polish() async {
        isPolishing = true
        defer { isPolishing = false }
        do {
            thought.polishedAttributedText = try await OpenAIService.fromSettings().polish(thought.rawAttributedText)
            showOriginal = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
