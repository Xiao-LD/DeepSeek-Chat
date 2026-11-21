import SwiftUI
import AVFoundation
import UIKit

struct MessageBubbleView: View {
    let message: ChatMessage
    @State private var synthesizer = AVSpeechSynthesizer()
    @State private var cursorVisible = true
    @Environment(\.colorScheme) var colorScheme // 🔥 引入环境
    
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
                        if message.isStreaming {
                            Rectangle().fill(Color.primary).frame(width: 8, height: 16)
                                .opacity(cursorVisible ? 1 : 0)
                                .onAppear { withAnimation(.easeInOut(duration: 0.5).repeatForever()) { cursorVisible = false } }
                        }
                    }
                } else if message.isStreaming && (message.reasoningContent ?? "").isEmpty {
                    ProgressView().controlSize(.small)
                }
            }
            .padding(14)
            // 🔥 彻底移除蓝色 tint。用户：浅黑/深白底色。AI：纯透明玻璃。
            .glassEffect(
                message.role == .user
                    ? .regular.tint(colorScheme == .dark ? .white.opacity(0.15) : .black.opacity(0.08))
                    : .regular,
                in: .rect(cornerRadius: 20)
            )
            .contextMenu {
                Button { UIPasteboard.general.string = message.content; UIImpactFeedbackGenerator(style: .light).impactOccurred() } label: { Label("复制文本", systemImage: "doc.on.doc") }
                Button { notificationManager.textToAppend = message.content } label: { Label("追加到输入框", systemImage: "arrow.down.left.and.arrow.up.right") }
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

class NotificationManager: ObservableObject {
    @Published var textToAppend: String? = nil
}

struct ShareImageView: View {
    let conversation: Conversation
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Image(systemName: "brain.head.profile").font(.largeTitle).foregroundStyle(.primary)
                VStack(alignment: .leading) {
                    Text("DeepSeek 对话分享").font(.headline)
                    Text(Date().formatted()).font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 10)
            ForEach(conversation.messages) { msg in
                VStack(alignment: .leading, spacing: 6) {
                    Text(msg.role == .user ? "我" : "DeepSeek").font(.caption).bold().foregroundStyle(.secondary)
                    MarkdownText(markdown: msg.content).padding(12)
                        .glassEffect(msg.role == .user ? .regular.tint(.black.opacity(0.1)) : .regular, in: .rect(cornerRadius: 12))
                }
            }
            Spacer()
        }
        .padding(24).frame(width: 400).background(Color(UIColor.systemBackground))
    }
}