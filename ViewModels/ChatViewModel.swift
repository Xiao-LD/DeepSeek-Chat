import Foundation
import SwiftUI
import UIKit

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var conversation: Conversation
    @Published var isStreaming = false
    @Published var errorMessage: String?
    
    // RAG 文档库
    @Published var ragChunks: [String] = []
    @Published var isRagEnabled = false

    private let service = DeepSeekService()
    private var streamTask: Task<Void, Never>?

    init(conversation: Conversation) {
        self.conversation = conversation
    }
    
    // 处理 RAG 切片
    func loadDocument(text: String) {
        let chunkSize = 800
        var chunks: [String] = []
        var currentIndex = text.startIndex
        while currentIndex < text.endIndex {
            let endIndex = text.index(currentIndex, offsetBy: chunkSize, limitedBy: text.endIndex) ?? text.endIndex
            let chunk = String(text[currentIndex..<endIndex])
            chunks.append(chunk)
            currentIndex = endIndex
        }
        self.ragChunks = chunks
        UIImpactFeedbackGenerator(style: .success).impactOccurred()
    }
    
    func send(_ text: String, imageBase64: String? = nil, useWebSearch: Bool = false) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (!trimmed.isEmpty || imageBase64 != nil), !isStreaming else { return }
        
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        
        // 暂时把图片塞进 ChatMessage content 里方便显示（实际发送时会剥离）
        let userMsg = ChatMessage(role: .user, content: trimmed + (imageBase64 != nil ? "\n[图片已附带]" : ""))
        conversation.messages.append(userMsg)
        
        executeRequest(promptText: trimmed, imageBase64: imageBase64, useWebSearch: useWebSearch)
    }
    
    func regenerate() {
        guard !isStreaming else { return }
        if let last = conversation.messages.last, last.role == .assistant { conversation.messages.removeLast() }
        let lastText = conversation.messages.last(where: { $0.role == .user })?.content.components(separatedBy: "\n[图片已附带]").first ?? ""
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        executeRequest(promptText: lastText, imageBase64: nil, useWebSearch: false)
    }
    
    private func executeRequest(promptText: String, imageBase64: String?, useWebSearch: Bool, isAutoGen: Bool = false) {
        let assistant = ChatMessage(role: .assistant, content: "", isStreaming: true)
        conversation.messages.append(assistant)
        
        let assistantID = assistant.id
        isStreaming = true
        errorMessage = nil
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()

        streamTask = Task {
            do {
                var apiMessages = buildAPIMessages()
                
                // 1. 注入 RAG
                if isRagEnabled && !ragChunks.isEmpty {
                    let relevant = ragChunks.filter { $0.contains(promptText.prefix(10)) }.prefix(2).joined(separator: "\n...\n")
                    if !relevant.isEmpty {
                        apiMessages.insert(APIMessage(role: "system", content: "以下是参考资料：\n\(relevant)"), at: 0)
                    }
                }
                
                // 2. 注入联网
                if useWebSearch {
                    let searchResult = try? await WebSearchService.shared.search(query: promptText)
                    if let res = searchResult, !res.isEmpty {
                        apiMessages.insert(APIMessage(role: "system", content: res), at: 0)
                    }
                }
                
                // 3. 用户消息（带图）
                if !isAutoGen {
                    // 去掉刚才为了显示塞进 content 的尾巴
                    apiMessages.removeLast()
                    apiMessages.append(APIMessage(role: "user", text: promptText, imageBase64: imageBase64))
                }

                for try await event in service.streamCompletion(
                    messages: apiMessages, model: conversation.model, temperature: conversation.temperature
                ) {
                    guard let idx = conversation.messages.firstIndex(where: { $0.id == assistantID }) else { continue }
                    switch event {
                    case .reasoningDelta(let delta):
                        conversation.messages[idx].reasoningContent = (conversation.messages[idx].reasoningContent ?? "") + delta
                    case .contentDelta(let delta):
                        conversation.messages[idx].content += delta
                    case .finished(let usage):
                        conversation.messages[idx].isStreaming = false
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
    
    // 🚀 AutoGen 双模型辩论
    func startAutoGen(topic: String) {
        guard !isStreaming else { return }
        conversation.messages.append(ChatMessage(role: .user, content: "启动双模型辩论：\(topic)"))
        executeAutoGenLoop(topic: topic, round: 1)
    }
    
    private func executeAutoGenLoop(topic: String, round: Int) {
        if round > 3 { return }
        let isV3 = round % 2 != 0
        let currentModel = isV3 ? DeepSeekModel.chat : DeepSeekModel.reasoner
        let roleName = isV3 ? "正方(V3)" : "反方(R1)"
        
        let prompt = round == 1 ? "请针对以下话题发表你的观点：\(topic)" : "请针对上一条观点进行反驳或补充。"
        
        let assistant = ChatMessage(role: .assistant, content: "【\(roleName) 思考中...】\n", isStreaming: true)
        conversation.messages.append(assistant)
        let id = assistant.id
        isStreaming = true
        
        streamTask = Task {
            do {
                var msgs = [APIMessage(role: "system", content: "你正在进行辩论，你的角色是\(roleName)。请用简短有力的语言表达。")]
                // 把之前的辩论记录加上
                for m in conversation.messages.filter({ $0.role != .system }).suffix(4) {
                    msgs.append(APIMessage(role: m.role.rawValue, content: m.content))
                }
                msgs.append(APIMessage(role: "user", content: prompt))
                
                for try await event in service.streamCompletion(messages: msgs, model: currentModel, temperature: 0.8) {
                    guard let idx = conversation.messages.firstIndex(where: { $0.id == id }) else { continue }
                    if case .contentDelta(let delta) = event {
                        conversation.messages[idx].content += delta
                    }
                }
                if let idx = conversation.messages.firstIndex(where: { $0.id == id }) {
                    conversation.messages[idx].isStreaming = false
                }
                isStreaming = false
                
                // 延迟 1 秒进行下一轮
                try await Task.sleep(nanoseconds: 1_000_000_000)
                executeAutoGenLoop(topic: topic, round: round + 1)
            } catch {
                isStreaming = false
            }
        }
    }

    func stop() {
        streamTask?.cancel()
        streamTask = nil
        isStreaming = false
        if let last = conversation.messages.indices.last { conversation.messages[last].isStreaming = false }
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
        if !conversation.systemPrompt.isEmpty { result.append(APIMessage(role: "system", content: conversation.systemPrompt)) }
        for msg in conversation.messages.filter({ $0.role != .system && !$0.isStreaming && !$0.content.isEmpty }).suffix(30) {
            result.append(APIMessage(role: msg.role.rawValue, content: msg.content))
        }
        return result
    }

    private func finalize(assistantID: UUID) {
        if let idx = conversation.messages.firstIndex(where: { $0.id == assistantID }) { conversation.messages[idx].isStreaming = false }
        isStreaming = false
        conversation.updatedAt = Date()
        if conversation.title == "新对话", let first = conversation.messages.first(where: { $0.role == .user }) {
            conversation.title = String(first.content.prefix(20))
        }
        StorageManager.shared.save(conversation)
    }
}