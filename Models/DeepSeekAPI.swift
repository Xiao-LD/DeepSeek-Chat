import Foundation

struct ChatCompletionRequest: Codable {
    let model: String
    let messages: [APIMessage]
    let temperature: Double
    let stream: Bool
    let maxTokens: Int?

    enum CodingKeys: String, CodingKey {
        case model, messages, temperature, stream
        case maxTokens = "max_tokens"
    }
}

// 🔥 升级：支持多模态图文混排
struct APIMessage: Codable {
    let role: String
    let content: Content
    
    // 如果只是普通文本
    init(role: String, content: String) {
        self.role = role
        self.content = .text(content)
    }
    
    // 如果有图片
    init(role: String, text: String, imageBase64: String?) {
        self.role = role
        if let img = imageBase64 {
            self.content = .multiPart([
                ["type": "text", "text": text],
                ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(img)"]]
            ])
        } else {
            self.content = .text(text)
        }
    }
    
    enum Content: Codable {
        case text(String)
        case multiPart([[String: String]])
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .text(let str):
                try container.encode(str)
            case .multiPart(let arr):
                try container.encode(arr)
            }
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let str = try? container.decode(String.self) {
                self = .text(str)
            } else {
                self = .multiPart([])
            }
        }
    }
}

struct ChatCompletionChunk: Decodable {
    let choices: [ChunkChoice]?
    let usage: Usage?
    struct ChunkChoice: Decodable {
        let delta: ChunkDelta
        let finishReason: String?
        enum CodingKeys: String, CodingKey { case delta, finishReason = "finish_reason" }
    }
    struct ChunkDelta: Decodable {
        let content: String?
        let reasoningContent: String?
        enum CodingKeys: String, CodingKey { case content, reasoningContent = "reasoning_content" }
    }
    struct Usage: Decodable {
        let promptTokens: Int?
        let completionTokens: Int?
        enum CodingKeys: String, CodingKey { case promptTokens = "prompt_tokens", completionTokens = "completion_tokens" }
    }
}

enum StreamEvent {
    case reasoningDelta(String)
    case contentDelta(String)
    case finished(usage: ChatCompletionChunk.Usage?)
}

enum DeepSeekError: LocalizedError {
    case invalidURL, invalidResponse, apiKeyMissing
    case httpError(statusCode: Int, body: String)
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "API 地址无效"
        case .invalidResponse: return "服务器响应无效"
        case .httpError(let code, let body):
            switch code {
            case 401: return "API Key 无效"
            case 402: return "账户余额不足"
            case 429: return "请求过于频繁"
            default: return "HTTP \(code): \(body.prefix(100))"
            }
        case .apiKeyMissing: return "请先在设置中配置 API Key"
        }
    }
}