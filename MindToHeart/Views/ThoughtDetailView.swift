import SwiftUI
import SwiftData

struct ThoughtDetailView: View {
    @Bindable var thought: Thought
    @State private var showOriginal = false
    @State private var isPolishing = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                DatePicker("日期", selection: $thought.date)
            }

            Section {
                Picker("版本", selection: $showOriginal) {
                    Text("润色后").tag(false)
                    Text("原文").tag(true)
                }
                .pickerStyle(.segmented)

                if showOriginal {
                    TextEditor(text: $thought.rawText)
                        .frame(minHeight: 220)
                } else if thought.polishedText.isEmpty {
                    Text("还没有润色版本")
                        .foregroundStyle(.secondary)
                } else {
                    TextEditor(text: $thought.polishedText)
                        .frame(minHeight: 220)
                }
            }

            Section {
                Button {
                    Task { await polish() }
                } label: {
                    HStack {
                        Label(thought.polishedText.isEmpty ? "润色" : "根据原文重新润色", systemImage: "wand.and.stars")
                        if isPolishing {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(isPolishing)

                ShareLink(item: showOriginal ? thought.rawText : thought.displayText) {
                    Label("分享 / 复制", systemImage: "square.and.arrow.up")
                }
            }
        }
        .navigationTitle(thought.date.formatted(date: .abbreviated, time: .omitted))
        .navigationBarTitleDisplayMode(.inline)
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
            thought.polishedText = try await OpenAIService.fromSettings().polish(thought.rawText)
            showOriginal = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
