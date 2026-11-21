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

// 🔥 彻底修复多模态结构，严格匹配 OpenAI/DeepSeek 格式
struct APIMessage: Codable {
    let role: String
    let content: Content
    
    init(role: String, content: String) {
        self.role = role
        self.content = .text(content)
    }
    
    init(role: String, text: String, imageBase64: String?) {
        self.role = role
        if let img = imageBase64 {
            let textPart = Content.ContentPart(type: "text", text: text, image_url: nil)
            let imagePart = Content.ContentPart(type: "image_url", text: nil, image_url: Content.ContentPart.ImageUrl(url: "data:image/jpeg;base64,\(img)"))
            self.content = .multiPart([textPart, imagePart])
        } else {
            self.content = .text(text)
        }
    }
    
    enum Content: Codable {
        case text(String)
        case multiPart([ContentPart])
        
        struct ContentPart: Codable {
            let type: String
            let text: String?
            let image_url: ImageUrl?
            
            struct ImageUrl: Codable {
                let url: String
            }
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .text(let str):
                try container.encode(str)
            case .multiPart(let parts):
                try container.encode(parts)
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