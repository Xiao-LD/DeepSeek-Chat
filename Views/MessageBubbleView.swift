import SwiftUI

struct MessageBubbleView: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 40) }

            VStack(alignment: .leading, spacing: 8) {
                if let reasoning = message.reasoningContent, !reasoning.isEmpty {
                    ThinkingView(text: reasoning, isStreaming: message.isStreaming)
                }

                if !message.content.isEmpty {
                    MarkdownText(markdown: message.content)
                        .textSelection(.enabled)
                } else if message.isStreaming && (message.reasoningContent ?? "").isEmpty {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .padding(12)
            .background {
                if message.role == .user {
                    // 用户气泡：带点蓝调的毛玻璃
                    Color.blue.opacity(0.25).background(.ultraThinMaterial)
                } else {
                    // AI 气泡：深色磨砂玻璃
                    Color.black.opacity(0.15).background(.regularMaterial)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                // 增加一圈微弱的高光边框，更有玻璃感
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )

            if message.role != .user { Spacer(minLength: 40) }
        }
    }
}