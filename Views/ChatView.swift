import SwiftUI
import UniformTypeIdentifiers
import PDFKit

struct ChatView: View {
    @StateObject private var viewModel: ChatViewModel
    @StateObject private var speech = SpeechRecognizer()
    
    @State private var input = ""
    @FocusState private var focused: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    @State private var showScrollToBottom = false
    
    // 扩展功能状态
    @State private var useWebSearch = false
    @State private var showPromptDialog = false
    @State private var tempPrompt = ""
    @State private var showFileImporter = false

    init(conversation: Conversation) {
        _viewModel = StateObject(wrappedValue: ChatViewModel(conversation: conversation))
    }

    var body: some View {
        ZStack {
            GlassBackground()

            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(viewModel.conversation.messages) { msg in
                                MessageBubbleView(message: msg)
                                    .id(msg.id)
                            }
                            Color.clear.frame(height: 1).id("BOTTOM_ANCHOR")
                                .onAppear { showScrollToBottom = false }
                                .onDisappear { showScrollToBottom = true }
                        }
                        .padding().padding(.bottom, 10)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { proxy.scrollTo("BOTTOM_ANCHOR", anchor: .bottom) }
                    }
                    .onChange(of: viewModel.conversation.messages.last?.content) { _ in
                        guard let last = viewModel.conversation.messages.last else { return }
                        if !showScrollToBottom {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                    .overlay(alignment: .bottomTrailing) {
                        if showScrollToBottom {
                            Button {
                                withAnimation { proxy.scrollTo("BOTTOM_ANCHOR", anchor: .bottom) }
                            } label: {
                                Image(systemName: "arrow.down").font(.system(size: 16, weight: .bold)).foregroundStyle(.primary).frame(width: 36, height: 36)
                                    .background(.ultraThinMaterial).clipShape(Circle()).shadow(radius: 3)
                            }
                            .padding(.trailing, 20).padding(.bottom, 10).transition(.scale.combined(with: .opacity))
                        }
                    }
                }

                if let error = viewModel.errorMessage {
                    Text(error).font(.caption).foregroundStyle(.red).padding(.horizontal)
                }

                // 底部工具栏 (文档上传 + 联网开关)
                HStack(spacing: 16) {
                    Button { showFileImporter = true } label: {
                        Image(systemName: "paperclip").foregroundStyle(.primary)
                    }
                    
                    Toggle(isOn: $useWebSearch) {
                        HStack(spacing: 4) {
                            Image(systemName: "globe")
                            Text("联网").font(.caption)
                        }
                    }
                    .toggleStyle(.button)
                    .tint(.blue)
                    .controlSize(.small)
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)

                HStack(alignment: .bottom, spacing: 12) {
                    Button {
                        if speech.isRecording { speech.stopRecording() } else { speech.startRecording() }
                    } label: {
                        Image(systemName: speech.isRecording ? "mic.fill" : "mic").font(.system(size: 20)).foregroundStyle(speech.isRecording ? .red : .primary).frame(width: 44, height: 44)
                            .background { Circle().fill(colorScheme == .dark ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.white)) }
                            .overlay(Circle().stroke(Color.primary.opacity(0.05), lineWidth: 1))
                            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.1 : 0.03), radius: 10, x: 0, y: 4)
                    }
                    .onChange(of: speech.transcribedText) { newText in
                        if !newText.isEmpty { input = newText }
                    }
                    
                    TextField("输入消息…", text: $input, axis: .vertical)
                        .lineLimit(1...5).focused($focused).padding(.horizontal, 16).padding(.vertical, 12)
                        .background { RoundedRectangle(cornerRadius: 24).fill(colorScheme == .dark ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.white)) }
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.primary.opacity(0.05), lineWidth: 1))
                        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.1 : 0.03), radius: 10, x: 0, y: 4)

                    Button {
                        if speech.isRecording { speech.stopRecording() }
                        if viewModel.isStreaming { viewModel.stop() } else {
                            viewModel.send(input, useWebSearch: useWebSearch)
                            input = ""
                        }
                    } label: {
                        Image(systemName: viewModel.isStreaming ? "stop.fill" : "arrow.up").font(.system(size: 18, weight: .bold)).foregroundStyle(.white).frame(width: 44, height: 44)
                            .background { Circle().fill(viewModel.isStreaming ? Color.red.opacity(0.8) : (input.trimmingCharacters(in: .whitespaces).isEmpty ? (colorScheme == .dark ? Color.gray.opacity(0.5) : Color.black.opacity(0.1)) : Color.blue)) }
                            .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                            .shadow(color: Color.blue.opacity(input.isEmpty || viewModel.isStreaming ? 0 : 0.4), radius: 8, x: 0, y: 4)
                    }
                    .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty && !viewModel.isStreaming)
                    .animation(.spring(), value: viewModel.isStreaming)
                }
                .padding(.horizontal, 16).padding(.bottom, 8)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: { Image(systemName: "chevron.left").font(.system(size: 16, weight: .bold)).foregroundStyle(.primary) }.buttonStyle(GlassButtonStyle())
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Section("系统提示词") {
                        Button { tempPrompt = viewModel.conversation.systemPrompt; showPromptDialog = true } label: { Label("设置角色", systemImage: "person.text.rectangle") }
                    }
                    Section("模型") {
                        Button { viewModel.changeModel(to: .chat) } label: { Label("DeepSeek V3", systemImage: "bolt.fill") }
                        Button { viewModel.changeModel(to: .reasoner) } label: { Label("DeepSeek R1", systemImage: "brain.head.profile") }
                    }
                    Section("操作") {
                        Button { viewModel.regenerate() } label: { Label("重新生成", systemImage: "arrow.clockwise") }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(viewModel.conversation.model == .chat ? "V3" : "R1").font(.system(size: 13, weight: .bold))
                        Image(systemName: "chevron.up.chevron.down").font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(.primary).padding(.horizontal, 12).padding(.vertical, 6)
                    .background { Capsule().fill(colorScheme == .dark ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.white)) }
                    .clipShape(Capsule()).overlay(Capsule().stroke(Color.primary.opacity(0.05), lineWidth: 1))
                }
            }
            ToolbarItem(placement: .principal) {
                Text(viewModel.conversation.model == .reasoner ? "DeepSeek R1" : "DeepSeek V3").font(.headline).foregroundStyle(.primary)
            }
        }
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        // 弹窗与文件选择器
        .alert("设置角色 (System Prompt)", isPresented: $showPromptDialog) {
            TextField("例如：你是一个资深翻译官", text: $tempPrompt, axis: .vertical)
            Button("取消", role: .cancel) {}
            Button("保存") { viewModel.conversation.systemPrompt = tempPrompt }
        }
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.pdf, .plainText]) { result in
            if let url = try? result.get(), url.startAccessingSecurityScopedResource() {
                defer { url.stopAccessingSecurityScopedResource() }
                if url.pathExtension.lowercased() == "pdf", let doc = PDFDocument(url: url) {
                    input += "\n[附件: \(url.lastPathComponent)]\n" + (doc.string ?? "")
                } else if let text = try? String(contentsOf: url) {
                    input += "\n[附件: \(url.lastPathComponent)]\n" + text
                }
            }
        }
    }
}