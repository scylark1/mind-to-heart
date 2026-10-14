import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsKey.apiKey) private var apiKey = ""
    @AppStorage(SettingsKey.chatModel) private var chatModel = OpenAIService.defaultChatModel
    @AppStorage(SettingsKey.transcribeModel) private var transcribeModel = OpenAIService.defaultTranscribeModel

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("sk-...", text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("OpenAI API Key")
                } footer: {
                    Text("在 platform.openai.com 创建。Key 只保存在这台手机上。")
                }

                Section("模型") {
                    LabeledContent("润色") {
                        TextField(OpenAIService.defaultChatModel, text: $chatModel)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("语音转文字") {
                        TextField(OpenAIService.defaultTranscribeModel, text: $transcribeModel)
                            .multilineTextAlignment(.trailing)
                    }
                }
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}
