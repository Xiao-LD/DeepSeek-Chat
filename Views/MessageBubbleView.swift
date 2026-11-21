import SwiftUI
import AVFoundation
import UIKit

struct MessageBubbleView: View {
    let message: ChatMessage
    @State private var synthesizer = AVSpeechSynthesizer()
    
    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 40) }

            VStack(alignment: .leading, spacing: 8) {
                if let reasoning = message.reasoningContent, !reasoning.isEmpty {
                    ThinkingView(text: reasoning, isStreaming: message.isStreaming)
                }

                if !message.content.isEmpty {
                    MarkdownText(markdown: message.content)
                } else if message.isStreaming && (message.reasoningContent ?? "").isEmpty {
                    ProgressView().controlSize(.small)
                }
            }
            .padding(12)
            .background {
                if message.role == .user {
                    Color.blue.opacity(0.25).background(.ultraThinMaterial)
                } else {
                    Color.black.opacity(0.15).background(.regularMaterial)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
            // 🔥 长按菜单
            .contextMenu {
                Button {
                    UIPasteboard.general.string = message.content
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Label("复制文本", systemImage: "doc.on.doc")
                }
                
                if message.role == .assistant {
                    Button {
                        let utterance = AVSpeechUtterance(string: message.content)
                        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
                        synthesizer.speak(utterance)
                    } label: {
                        Label("朗读", systemImage: "play.circle")
                    }
                }
            }

            if message.role != .user { Spacer(minLength: 40) }
        }
    }
}