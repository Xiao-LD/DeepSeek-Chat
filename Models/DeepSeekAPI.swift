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

struct APIMessage: Codable {
    let role: String
    let content: String
}

struct ChatCompletionChunk: Decodable {
    let choices: [ChunkChoice]?
    let usage: Usage?

    struct ChunkChoice: Decodable {
        let delta: ChunkDelta
        let finishReason: String?

        enum CodingKeys: String, CodingKey {
            case delta
            case finishReason = "finish_reason"
        }
    }

    struct ChunkDelta: Decodable {
        let content: String?
        let reasoningContent: String?

        enum CodingKeys: String, CodingKey {
            case content
            case reasoningContent = "reasoning_content"
        }
    }

    struct Usage: Decodable {
        let promptTokens: Int?
        let completionTokens: Int?

        enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
        }
    }
}

enum StreamEvent {
    case reasoningDelta(String)
    case contentDelta(String)
    case finished(usage: ChatCompletionChunk.Usage?)
}

enum DeepSeekError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, body: String)
    case apiKeyMissing

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "API 地址无效"
        case .invalidResponse: return "服务器响应无效"
        case .httpError(let code, let body):
            switch code {
            case 401: return "API Key 无效，请检查设置"
            case 402: return "账户余额不足"
            case 429: return "请求过于频繁，请稍后重试"
            default: return "HTTP \(code): \(body.prefix(120))"
            }
        case .apiKeyMissing: return "请先在设置中配置 DeepSeek API Key"
        }
    }
}