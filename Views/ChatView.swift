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
                    HStack(alignment: .bottom, spacing: 12) {
                        TextField("输入消息…", text: $input, axis: .vertical)
                            .lineLimit(1...5)
                            .focused($focused)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
                            )

                        // 极度精致的液态发送按钮
                        Button {
                            if viewModel.isStreaming {
                                viewModel.stop()
                            } else {
                                viewModel.send(input)
                                input = ""
                            }
                        } label: {
                            Image(systemName: viewModel.isStreaming ? "stop.fill" : "arrow.up")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .background {
                                    Circle()
                                        .fill(
                                            viewModel.isStreaming ? Color.red.opacity(0.8) :
                                            (input.trimmingCharacters(in: .whitespaces).isEmpty ? Color.gray.opacity(0.4) : Color.blue)
                                        )
                                }
                                .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                                .shadow(color: Color.blue.opacity(0.4), radius: 8, x: 0, y: 4)
                        }
                        .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty && !viewModel.isStreaming)
                        .animation(.spring(), value: viewModel.isStreaming)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
                .overlay(
                    Rectangle()
                        .fill(Color.white.opacity(0.05))
                        .frame(height: 1),
                    alignment: .top
                )
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // 顶部导航栏右侧的模型切换按钮
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        viewModel.changeModel(to: .chat)
                    } label: {
                        Label("DeepSeek V3 (快速)", systemImage: "bolt.fill")
                    }
                    Button {
                        viewModel.changeModel(to: .reasoner)
                    } label: {
                        Label("DeepSeek R1 (推理)", systemImage: "brain.head.profile")
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(viewModel.conversation.model == .chat ? "V3" : "R1")
                            .font(.system(size: 13, weight: .bold))
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
                }
                .disabled(viewModel.isStreaming) // 发送中禁止切换模型
            }
            
            // 顶部导航栏的标题
            ToolbarItem(placement: .principal) {
                Text(viewModel.conversation.model == .reasoner ? "DeepSeek R1" : "DeepSeek V3")
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
        }
        // 让原生导航栏也变成透明毛玻璃
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}