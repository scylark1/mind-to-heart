import Foundation

enum SettingsKey {
    static let apiKey = "openai.apiKey"
    static let chatModel = "openai.chatModel"
    static let transcribeModel = "openai.transcribeModel"
}

/// 调用 OpenAI：语音转文字 + 润色。
struct OpenAIService {
    static let defaultChatModel = "gpt-6-luna"
    static let defaultTranscribeModel = "gpt-transcribe"

    var apiKey: String
    var chatModel = Self.defaultChatModel
    var transcribeModel = Self.defaultTranscribeModel

    /// 从「设置」里读取 API Key 和模型
    static func fromSettings() -> OpenAIService {
        let defaults = UserDefaults.standard
        func value(_ key: String, _ fallback: String) -> String {
            let v = defaults.string(forKey: key)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return v.isEmpty ? fallback : v
        }
        return OpenAIService(
            apiKey: value(SettingsKey.apiKey, ""),
            chatModel: value(SettingsKey.chatModel, defaultChatModel),
            transcribeModel: value(SettingsKey.transcribeModel, defaultTranscribeModel)
        )
    }

    var hasAPIKey: Bool { !apiKey.isEmpty }

    static let polishPrompt = """
    你是一个帮助用户整理随想的助手。用户会给你一段语音转写或随手打下的文字，请：
    1. 去掉口头禅、重复和明显的语病；
    2. 理顺逻辑，让表达清晰易懂；
    3. 保留用户的原意、语气和第一人称，不要添加用户没有表达过的观点或信息；
    4. 内容较长时可以适当分段；
    5. 文字里可能有 Markdown 格式：# 标题、## 小标题、**加粗**、*斜体*、~~删除线~~、<u>下划线</u>、- 列表。\
    请保留这些格式，让它们继续作用在对应的内容上；不要新增原文没有的格式。
    只输出整理后的正文（保留上面的格式标记），不要自己加标题、解释或任何额外的话，也不要用代码块包起来。
    """

    // MARK: - 语音转文字

    func transcribe(fileURL: URL) async throws -> String {
        guard hasAPIKey else { throw ServiceError.missingAPIKey }

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/audio/transcriptions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        func appendField(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
            body.append("\(value)\r\n")
        }
        appendField("model", transcribeModel)
        appendField("prompt", "以下是一段随口说的想法，请使用简体中文。")

        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.m4a\"\r\n")
        body.append("Content-Type: audio/m4a\r\n\r\n")
        body.append(try Data(contentsOf: fileURL))
        body.append("\r\n--\(boundary)--\r\n")
        request.httpBody = body

        struct Response: Decodable { let text: String }
        let response: Response = try await send(request)
        return response.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - 润色

    func polish(_ text: String) async throws -> String {
        guard hasAPIKey else { throw ServiceError.missingAPIKey }

        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "model": chatModel,
            "messages": [
                ["role": "system", "content": Self.polishPrompt],
                ["role": "user", "content": text],
            ],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        struct Response: Decodable {
            struct Choice: Decodable {
                struct Message: Decodable { let content: String? }
                let message: Message
            }
            let choices: [Choice]
        }
        let response: Response = try await send(request)
        guard let content = response.choices.first?.message.content else {
            throw ServiceError.emptyResponse
        }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - 网络请求

    private func send<T: Decodable>(_ request: URLRequest) async throws -> T {
        var request = request
        request.timeoutInterval = 120
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            let message = (try? JSONDecoder().decode(APIError.self, from: data))?.error.message
                ?? String(data: data, encoding: .utf8)
                ?? "未知错误"
            throw ServiceError.api(status: status, message: message)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    /// OpenAI 出错时返回的 JSON：{"error": {"message": "..."}}
    private struct APIError: Decodable {
        struct Detail: Decodable { let message: String }
        let error: Detail
    }

    enum ServiceError: LocalizedError {
        case missingAPIKey
        case emptyResponse
        case api(status: Int, message: String)

        var errorDescription: String? {
            switch self {
            case .missingAPIKey:
                return "请先在「设置」里填写 OpenAI API Key"
            case .emptyResponse:
                return "AI 没有返回内容"
            case let .api(status, message):
                return "OpenAI 请求失败（\(status)）：\(message)"
            }
        }
    }
}

private extension Data {
    mutating func append(_ string: String) {
        append(Data(string.utf8))
    }
}
