import Foundation

struct Conversation: Identifiable, Codable {
    let id: UUID
    var title: String
    var messages: [ChatMessage]
    var systemPrompt: String
    var model: DeepSeekModel
    var temperature: Double
    var createdAt: Date
    var updatedAt: Date
}

enum DeepSeekModel: String, Codable, CaseIterable, Identifiable {
    case chat = "deepseek-chat"
    case reasoner = "deepseek-reasoner"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .chat: return "DeepSeek Chat (V3)"
        case .reasoner: return "DeepSeek Reasoner (R1)"
        }
    }

    var supportsReasoning: Bool { self == .reasoner }
}