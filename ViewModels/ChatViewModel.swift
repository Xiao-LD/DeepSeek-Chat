import Foundation
import SwiftUI
import UIKit

@MainActor
final class ChatViewModel: ObservableObject {

    @Published var conversation: Conversation
    @Published var isStreaming = false
    @Published var errorMessage: String?

    private let service = DeepSeekService()
    private var streamTask: Task<Void, Never>?

    init(conversation: Conversation) {
        self.conversation = conversation
    }
    
    func send(_ text: String, useWebSearch: Bool = false) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isStreaming else { return }
        
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        conversation.messages.append(ChatMessage(role: .user, content: trimmed))
        executeRequest(useWebSearch: useWebSearch)
    }
    
    // 重新生成最后一条回复
    func regenerate() {
        guard !isStreaming else { return }
        if let last = conversation.messages.last, last.role == .assistant {
            conversation.messages.removeLast()
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        executeRequest(useWebSearch: false)
    }
    
    // 内部请求逻辑
    private func executeRequest(useWebSearch: Bool) {
        let assistant = ChatMessage(role: .assistant, content: "", isStreaming: true)
        conversation.messages.append(assistant)
        
        let assistantID = assistant.id
        isStreaming = true
        errorMessage = nil
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()

        streamTask = Task {
            do {
                var apiMessages = buildAPIMessages()
                
                // 联网搜索逻辑
                if useWebSearch, let lastUserMsg = conversation.messages.last(where: { $0.role == .user })?.content {
                    let searchResult = try await WebSearchService.shared.search(query: lastUserMsg)
                    if !searchResult.isEmpty {
                        // 将搜索结果作为 System 注入
                        apiMessages.insert(APIMessage(role: "system", content: searchResult), at: 0)
                    }
                }

                for try await event in service.streamCompletion(
                    messages: apiMessages,
                    model: conversation.model,
                    temperature: conversation.temperature
                ) {
                    guard let idx = conversation.messages.firstIndex(where: { $0.id == assistantID }) else { continue }

                    switch event {
                    case .reasoningDelta(let delta):
                        conversation.messages[idx].reasoningContent = (conversation.messages[idx].reasoningContent ?? "") + delta
                    case .contentDelta(let delta):
                        conversation.messages[idx].content += delta
                    case .finished(let usage):
                        conversation.messages[idx].isStreaming = false
                        // 统计 Token
                        if let u = usage {
                            let currentPrompt = UserDefaults.standard.integer(forKey: "totalPromptTokens")
                            let currentComp = UserDefaults.standard.integer(forKey: "totalCompletionTokens")
                            UserDefaults.standard.set(currentPrompt + (u.promptTokens ?? 0), forKey: "totalPromptTokens")
                            UserDefaults.standard.set(currentComp + (u.completionTokens ?? 0), forKey: "totalCompletionTokens")
                        }
                    }
                }

                finalize(assistantID: assistantID)

            } catch {
                errorMessage = error.localizedDescription
                finalize(assistantID: assistantID)
            }
        }
    }

    func stop() {
        streamTask?.cancel()
        streamTask = nil
        isStreaming = false
        if let last = conversation.messages.indices.last {
            conversation.messages[last].isStreaming = false
        }
    }
    
    func changeModel(to model: DeepSeekModel) {
        guard !isStreaming else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        conversation.model = model
        conversation.updatedAt = Date()
        StorageManager.shared.save(conversation)
    }

    private func buildAPIMessages() -> [APIMessage] {
        var result: [APIMessage] = []
        if !conversation.systemPrompt.isEmpty {
            result.append(APIMessage(role: "system", content: conversation.systemPrompt))
        }
        let history = conversation.messages
            .filter { $0.role != .system && !$0.isStreaming && !$0.content.isEmpty }
            .suffix(30)

        for msg in history {
            result.append(APIMessage(role: msg.role.rawValue, content: msg.content))
        }
        return result
    }

    private func finalize(assistantID: UUID) {
        if let idx = conversation.messages.firstIndex(where: { $0.id == assistantID }) {
            conversation.messages[idx].isStreaming = false
        }
        isStreaming = false
        conversation.updatedAt = Date()
        if conversation.title == "新对话", let first = conversation.messages.first(where: { $0.role == .user }) {
            conversation.title = String(first.content.prefix(20))
        }
        StorageManager.shared.save(conversation)
    }
}