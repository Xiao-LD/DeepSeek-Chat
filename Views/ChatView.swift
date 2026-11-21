import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import PDFKit

struct ChatView: View {
    @StateObject private var viewModel: ChatViewModel
    @StateObject private var speech = SpeechRecognizer()
    @StateObject private var notificationManager = NotificationManager()
    
    @State private var input = ""
    @FocusState private var focused: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    @State private var showScrollToBottom = false
    @State private var useWebSearch = false
    @State private var showPromptDialog = false
    @State private var tempPrompt = ""
    @State private var showFileImporter = false
    @State private var showAutoGenDialog = false
    @State private var autoGenTopic = ""
    
    // 图片相关
    @State private var selectedImage: UIImage?
    @State private var showPhotoPicker = false
    @State private var photoItem: PhotosPickerItem?

    let promptTemplates = [
        ("翻译", "你是一位精通中英双语的资深翻译官，请将我接下来的内容翻译成地道的英文。"),
        ("代码", "你是一位资深软件工程师，请审查我接下来的代码，指出潜在Bug并提供优化建议。"),
        ("小红书", "你是一位小红书爆款文案专家，请根据我的主题，写一篇带有Emoji、排版精美的种草文案。"),
        ("总结", "请帮我总结我接下来发送的长文本，提取核心要点，用不超过 200 字概括。")
    ]

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
                                MessageBubbleView(message: msg).environmentObject(notificationManager).id(msg.id)
                            }
                            Color.clear.frame(height: 1).id("BOTTOM_ANCHOR")
                                .onAppear { showScrollToBottom = false }.onDisappear { showScrollToBottom = true }
                        }
                        .padding().padding(.bottom, 10)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { proxy.scrollTo("BOTTOM_ANCHOR", anchor: .bottom) } }
                    .onChange(of: viewModel.conversation.messages.last?.content) { _ in
                        guard let last = viewModel.conversation.messages.last else { return }
                        if !showScrollToBottom { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
                    }
                    .overlay(alignment: .bottomTrailing) {
                        if showScrollToBottom {
                            Button { withAnimation { proxy.scrollTo("BOTTOM_ANCHOR", anchor: .bottom) } } label: {
                                Image(systemName: "arrow.down").font(.system(size: 16, weight: .bold)).foregroundStyle(.primary).frame(width: 36, height: 36)
                                    .background(.ultraThinMaterial).clipShape(Circle()).shadow(radius: 3)
                            }.padding(.trailing, 20).padding(.bottom, 10).transition(.scale.combined(with: .opacity))
                        }
                    }
                }

                if let error = viewModel.errorMessage { Text(error).font(.caption).foregroundStyle(.red).padding(.horizontal) }

                // 🔥 选中的图片预览
                if let img = selectedImage {
                    HStack {
                        Image(uiImage: img).resizable().scaledToFill().frame(width: 60, height: 60).clipShape(RoundedRectangle(cornerRadius: 8))
                        Button { selectedImage = nil } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.gray) }
                        Spacer()
                    }.padding(.horizontal, 20).padding(.top, 8)
                }

                // 底部工具栏 (附图、文件、RAG、联网)
                HStack(spacing: 16) {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Image(systemName: "photo").foregroundStyle(.primary)
                    }
                    .onChange(of: photoItem) { newItem in
                        Task {
                            if let data = try? await newItem?.loadTransferable(type: Data.self), let uiImg = UIImage(data: data) {
                                // 压缩图片以免 Base64 过长
                                let resized = uiImg.jpegData(compressionQuality: 0.5)
                                selectedImage = UIImage(data: resized ?? data)
                            }
                        }
                    }
                    
                    Button { showFileImporter = true } label: { Image(systemName: "doc.text").foregroundStyle(viewModel.isRagEnabled ? .blue : .primary) }
                    
                    Menu {
                        ForEach(promptTemplates, id: \.0) { template in
                            Button(template.0) { input = template.1 + "\n" + input; focused = true }
                        }
                    } label: { Image(systemName: "wand.and.stars").foregroundStyle(.primary) }
                    
                    Toggle("联网", isOn: $useWebSearch).toggleStyle(.button).tint(.blue).controlSize(.small)
                    Spacer()
                }
                .padding(.horizontal, 20).padding(.vertical, 8)

                // 🔥 模仿官方的输入框
                HStack(alignment: .bottom, spacing: 12) {
                    Button {
                        if speech.isRecording { speech.stopRecording() } else { speech.startRecording() }
                    } label: {
                        Image(systemName: speech.isRecording ? "mic.fill" : "mic").font(.system(size: 20)).foregroundStyle(speech.isRecording ? .red : .primary).frame(width: 40, height: 40)
                    }
                    .onChange(of: speech.transcribedText) { newText in if !newText.isEmpty { input = newText } }
                    
                    TextField("给 DeepSeek 发送消息", text: $input, axis: .vertical)
                        .lineLimit(1...5).focused($focused).padding(.vertical, 10)
                    
                    Button {
                        if speech.isRecording { speech.stopRecording() }
                        if viewModel.isStreaming { viewModel.stop() } else {
                            var b64: String? = nil
                            if let img = selectedImage { b64 = img.jpegData(compressionQuality: 0.5)?.base64EncodedString() }
                            viewModel.send(input, imageBase64: b64, useWebSearch: useWebSearch)
                            input = ""; selectedImage = nil
                        }
                    } label: {
                        Image(systemName: viewModel.isStreaming ? "stop.circle.fill" : "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(input.isEmpty && selectedImage == nil && !viewModel.isStreaming ? Color.gray.opacity(0.5) : Color(hex: UserDefaults.standard.string(forKey: "accentColorHex") ?? "#007AFF"))
                    }
                    .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty && selectedImage == nil && !viewModel.isStreaming)
                }
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(colorScheme == .dark ? Color(white: 0.15) : Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .padding(.horizontal, 16).padding(.bottom, 8)
                .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
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
                    Section("角色提示词") { Button { tempPrompt = viewModel.conversation.systemPrompt; showPromptDialog = true } label: { Label("设置角色", systemImage: "person.text.rectangle") } }
                    Section("模型") {
                        Button { viewModel.changeModel(to: .chat) } label: { Label("DeepSeek V3", systemImage: "bolt.fill") }
                        Button { viewModel.changeModel(to: .reasoner) } label: { Label("DeepSeek R1", systemImage: "brain.head.profile") }
                    }
                    Section("多智能体") { Button { showAutoGenDialog = true } label: { Label("双模型辩论", systemImage: "bubble.left.and.bubble.right.fill") } }
                    Section("操作") { Button { viewModel.regenerate() } label: { Label("重新生成", systemImage: "arrow.clockwise") } }
                } label: {
                    Image(systemName: "ellipsis.circle").font(.title3).foregroundStyle(.primary)
                }
            }
            ToolbarItem(placement: .principal) {
                Text(viewModel.conversation.model == .reasoner ? "DeepSeek R1" : "DeepSeek V3").font(.headline).foregroundStyle(.primary)
            }
        }
        .alert("设置角色", isPresented: $showPromptDialog) { TextField("输入指令", text: $tempPrompt); Button("保存") { viewModel.conversation.systemPrompt = tempPrompt } }
        .alert("发起辩论", isPresented: $showAutoGenDialog) {
            TextField("输入辩论话题", text: $autoGenTopic)
            Button("开始") { viewModel.startAutoGen(topic: autoGenTopic); autoGenTopic = "" }
        }
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.pdf, .plainText]) { result in
            if let url = try? result.get(), url.startAccessingSecurityScopedResource() {
                defer { url.stopAccessingSecurityScopedResource() }
                if url.pathExtension.lowercased() == "pdf", let doc = PDFDocument(url: url) {
                    viewModel.loadDocument(text: doc.string ?? "")
                    viewModel.isRagEnabled = true // 开启了 RAG
                } else if let text = try? String(contentsOf: url) {
                    viewModel.loadDocument(text: text)
                    viewModel.isRagEnabled = true
                }
            }
        }
        .onChange(of: notificationManager.textToAppend) { newText in
            if let text = newText { input += text; notificationManager.textToAppend = nil; focused = true }
        }
    }
}