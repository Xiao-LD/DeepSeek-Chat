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
            .background(message.role == .user
                        ? Color.accentColor.opacity(0.15)
                        : Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))

            if message.role != .user { Spacer(minLength: 40) }
        }
    }
}