import SwiftUI
import AVFoundation
import UIKit

struct MessageBubbleView: View {
    let message: ChatMessage
    @State private var synthesizer = AVSpeechSynthesizer()
    @State private var cursorVisible = true
    
    // 用于通知输入框追加内容
    @EnvironmentObject var notificationManager: NotificationManager
    
    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 40) }

            VStack(alignment: .leading, spacing: 8) {
                if let reasoning = message.reasoningContent, !reasoning.isEmpty {
                    ThinkingView(text: reasoning, isStreaming: message.isStreaming)
                }

                if !message.content.isEmpty {
                    HStack(alignment: .bottom, spacing: 2) {
                        MarkdownText(markdown: message.content)
                        // 流式打字光标
                        if message.isStreaming {
                            Rectangle()
                                .fill(Color.primary)
                                .frame(width: 8, height: 16)
                                .opacity(cursorVisible ? 1 : 0)
                                .onAppear {
                                    withAnimation(.easeInOut(duration: 0.5).repeatForever()) { cursorVisible = false }
                                }
                        }
                    }
                } else if message.isStreaming && (message.reasoningContent ?? "").isEmpty {
                    ProgressView().controlSize(.small)
                }
            }
            .padding(12)
            .background {
                if message.role == .user {
                    Color(hex: UserDefaults.standard.string(forKey: "accentColorHex") ?? "#007AFF").opacity(0.25).background(.ultraThinMaterial)
                } else {
                    Color.black.opacity(0.15).background(.regularMaterial)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.white.opacity(0.15), lineWidth: 1))
            .contextMenu {
                Button {
                    UIPasteboard.general.string = message.content
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: { Label("复制文本", systemImage: "doc.on.doc") }
                
                Button {
                    notificationManager.textToAppend = message.content
                } label: { Label("追加到输入框", systemImage: "arrow.down.left.and.arrow.up.right") }
                
                if message.role == .assistant {
                    Button {
                        let utterance = AVSpeechUtterance(string: message.content)
                        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
                        synthesizer.speak(utterance)
                    } label: { Label("朗读", systemImage: "play.circle") }
                }
            }

            if message.role != .user { Spacer(minLength: 40) }
        }
    }
}

// 一个轻量级的全局通知中心，用于实现跨视图通信
class NotificationManager: ObservableObject {
    @Published var textToAppend: String? = nil
}