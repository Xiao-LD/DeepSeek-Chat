import SwiftUI

struct ChatView: View {
    @StateObject private var viewModel: ChatViewModel
    @State private var input = ""
    @FocusState private var focused: Bool

    init(conversation: Conversation) {
        _viewModel = StateObject(wrappedValue: ChatViewModel(conversation: conversation))
    }

    var body: some View {
        VStack(spacing: 0) {
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

            Divider()

            HStack(alignment: .bottom, spacing: 10) {
                TextField("输入消息…", text: $input, axis: .vertical)
                    .lineLimit(1...5)
                    .focused($focused)
                    .padding(10)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 18))

                Button {
                    if viewModel.isStreaming {
                        viewModel.stop()
                    } else {
                        viewModel.send(input)
                        input = ""
                    }
                } label: {
                    Image(systemName: viewModel.isStreaming ? "stop.circle.fill" : "arrow.up.circle.fill")
                        .font(.system(size: 30))
                }
                .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty && !viewModel.isStreaming)
            }
            .padding()
        }
        .navigationTitle(viewModel.conversation.model == .reasoner ? "R1 推理" : "Chat")
        .navigationBarTitleDisplayMode(.inline)
    }
}