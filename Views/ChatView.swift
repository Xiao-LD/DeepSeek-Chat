import SwiftUI

struct ChatView: View {
    @StateObject private var viewModel: ChatViewModel
    @State private var input = ""
    @FocusState private var focused: Bool

    init(conversation: Conversation) {
        _viewModel = StateObject(wrappedValue: ChatViewModel(conversation: conversation))
    }

    var body: some View {
        ZStack {
            // 1. 全局炫酷渐变背景
            LinearGradient(
                colors: [Color.black, Color(red: 0.08, green: 0.08, blue: 0.15)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // 2. 聊天记录区域
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(viewModel.conversation.messages) { msg in
                                MessageBubbleView(message: msg)
                                    .id(msg.id)
                            }
                        }
                        .padding()
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: viewModel.conversation.messages.last?.content) { _ in
                        guard let last = viewModel.conversation.messages.last else { return }
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }

                // 3. 底部输入区域（液态玻璃质感）
                VStack {
                    HStack(alignment: .bottom, spacing: 10) {
                        TextField("输入消息…", text: $input, axis: .vertical)
                            .lineLimit(1...5)
                            .focused($focused)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )

                        Button {
                            if viewModel.isStreaming {
                                viewModel.stop()
                            } else {
                                viewModel.send(input)
                                input = ""
                            }
                        } label: {
                            Image(systemName: viewModel.isStreaming ? "stop.circle.fill" : "arrow.up.circle.fill")
                                .font(.system(size: 34))
                                .foregroundStyle(
                                    input.trimmingCharacters(in: .whitespaces).isEmpty && !viewModel.isStreaming
                                    ? Color.gray.opacity(0.6) : Color.blue
                                )
                                .background(Circle().fill(.ultraThinMaterial))
                        }
                        .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty && !viewModel.isStreaming)
                    }
                }
                .padding()
            }
        }
        .navigationTitle(viewModel.conversation.model == .reasoner ? "R1 推理" : "Chat")
        .navigationBarTitleDisplayMode(.inline)
    }
}