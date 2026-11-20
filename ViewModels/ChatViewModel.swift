import Foundation
import SwiftUI

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

    func send(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isStreaming else { return }

        conversation.messages.append(
            ChatMessage(role: .user, content: trimmed)
        )
        let assistant = ChatMessage(
            role: .assistant, content: "", isStreaming: true
        )
        conversation.messages.append(assistant)

        let assistantID = assistant.id
        isStreaming = true
        errorMessage = nil

        streamTask = Task {
            do {
                let apiMessages = buildAPIMessages()

                for try await event in service.streamCompletion(
                    messages: apiMessages,
                    model: conversation.model,
                    temperature: conversation.temperature
                ) {
                    guard let idx = conversation.messages.firstIndex(
                        where: { $0.id == assistantID }
                    ) else { continue }

                    switch event {
                    case .reasoningDelta(let delta):
                        conversation.messages[idx].reasoningContent =
                            (conversation.messages[idx].reasoningContent ?? "") + delta
                    case .contentDelta(let delta):
                        conversation.messages[idx].content += delta
                    case .finished:
                        conversation.messages[idx].isStreaming = false
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

    private func buildAPIMessages() -> [APIMessage] {
        var result: [APIMessage] = []

        if !conversation.systemPrompt.isEmpty {
            result.append(APIMessage(role: "system", content: conversation.systemPrompt))
        }

        let history = conversation.messages
            .filter { $0.role != .system && !$0.isStreaming && !$0.content.isEmpty }
            .suffix(30)

        for msg in history {
            result.append(
                APIMessage(role: msg.role.rawValue, content: msg.content)
            )
        }
        return result
    }

    private func finalize(assistantID: UUID) {
        if let idx = conversation.messages.firstIndex(where: { $0.id == assistantID }) {
            conversation.messages[idx].isStreaming = false
        }
        isStreaming = false
        conversation.updatedAt = Date()
        if conversation.title == "新对话",
           let first = conversation.messages.first(where: { $0.role == .user }) {
            conversation.title = String(first.content.prefix(20))
        }
        StorageManager.shared.save(conversation)
    }
}