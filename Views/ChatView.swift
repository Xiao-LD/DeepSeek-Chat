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
    @State private var showPromptDialog = false
    @State private var tempPrompt = ""
    @State private var showFileImporter = false
    @State private var showAutoGenDialog = false
    @State private var autoGenTopic = ""
    
    @State private var selectedImage: UIImage?
    @State private var photoItem: PhotosPickerItem?

    init(conversation: Conversation) {
        _viewModel = StateObject(wrappedValue: ChatViewModel(conversation: conversation))
    }

    var body: some View {
        ZStack(alignment: .top) {
            (colorScheme == .dark ? Color.black : Color.white).ignoresSafeArea()
            
            ScrollViewReader { proxy in
                ScrollView {
                    if viewModel.conversation.messages.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "fish.fill")
                                .font(.system(size: 50)).foregroundStyle(.primary).rotationEffect(.degrees(-90))
                            Text("有什么可以帮忙的？")
                                .font(.title2.bold()).foregroundStyle(.primary)
                        }
                        .frame(maxWidth: .infinity).padding(.top, 150)
                    } else {
                        LazyVStack(spacing: 20) {
                            ForEach(viewModel.conversation.messages) { msg in
                                MessageBubbleView(message: msg)
                                    .environmentObject(notificationManager)
                                    .id(msg.id)
                            }
                            Color.clear.frame(height: 1).id("BOTTOM_ANCHOR")
                                .onAppear { showScrollToBottom = false }
                                .onDisappear { showScrollToBottom = true }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 100)
                        .padding(.bottom, 20)
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                // 🔥 启用 iOS 26 原生边缘柔边模糊 SDK (ScrollEdgeEffect)
                .scrollEdgeEffectStyle(.soft, for: .top)
                .scrollEdgeEffectStyle(.soft, for: .bottom)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { proxy.scrollTo("BOTTOM_ANCHOR", anchor: .bottom) }
                }
                .onChange(of: viewModel.conversation.messages.last?.content) { _ in
                    guard let last = viewModel.conversation.messages.last else { return }
                    if !showScrollToBottom { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
                }
                .overlay(alignment: .bottomTrailing) {
                    if showScrollToBottom {
                        Button { withAnimation { proxy.scrollTo("BOTTOM_ANCHOR", anchor: .bottom) } } label: {
                            Image(systemName: "arrow.down").font(.system(size: 16, weight: .bold)).foregroundStyle(.primary).frame(width: 36, height: 36)
                                .glassEffect(.regular.interactive(), in: .circle)
                        }.padding(.trailing, 20).padding(.bottom, 110).transition(.scale.combined(with: .opacity))
                    }
                }
            }
            
            // 顶部悬浮按钮组
            VStack(spacing: 0) {
                GlassEffectContainer(spacing: 16) {
                    HStack {
                        Button { dismiss() } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .bold))
                                .frame(width: 44, height: 44)
                                .glassEffect(.regular.interactive(), in: .circle)
                        }
                        
                        Spacer()
                        
                        Menu {
                            Button { viewModel.changeModel(to: .chat) } label: { Label("DeepSeek V3 (极速)", systemImage: "bolt.fill") }
                            Button { viewModel.changeModel(to: .reasoner) } label: { Label("DeepSeek R1 (推理)", systemImage: "brain.head.profile") }
                            Section("工具") {
                                Button { showAutoGenDialog = true } label: { Label("双模型辩论", systemImage: "bubble.left.and.bubble.right") }
                                Button { tempPrompt = viewModel.conversation.systemPrompt; showPromptDialog = true } label: { Label("角色设定", systemImage: "person.text.rectangle") }
                            }
                        } label: {
                            Text(viewModel.conversation.model == .chat ? "DeepSeek Flash" : "DeepSeek Reason")
                                .font(.system(size: 16, weight: .bold))
                                .padding(.horizontal, 20).padding(.vertical, 12)
                                .glassEffect(.regular.interactive(), in: .capsule)
                        }
                        
                        Spacer()
                        
                        // 🔥 已去掉耳机，换成了更实用的“重新生成”
                        Button { viewModel.regenerate() } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 18, weight: .bold))
                                .frame(width: 44, height: 44)
                                .glassEffect(.regular.interactive(), in: .circle)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 50)
                }
            }
        }
        .navigationBarHidden(true)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 6) {
                if let error = viewModel.errorMessage { Text(error).font(.caption).foregroundStyle(.red) }
                if let img = selectedImage {
                    HStack {
                        Image(uiImage: img).resizable().scaledToFill().frame(width: 50, height: 50).clipShape(RoundedRectangle(cornerRadius: 8))
                        Button { selectedImage = nil } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.gray) }
                        Spacer()
                    }.padding(.horizontal, 20)
                }

                VStack(alignment: .leading, spacing: 12) {
                    TextField("发消息或按住说话", text: $input, axis: .vertical)
                        .lineLimit(1...5).focused($focused).padding(.horizontal, 8).padding(.top, 8)
                    
                    GlassEffectContainer(spacing: 8) {
                        HStack {
                            Button {
                                viewModel.changeModel(to: viewModel.conversation.model == .reasoner ? .chat : .reasoner)
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "atom")
                                    Text(viewModel.conversation.model == .reasoner ? "思考·已开启" : "思考")
                                }.font(.system(size: 14, weight: .medium)).padding(.horizontal, 12).padding(.vertical, 8)
                                .glassEffect(viewModel.conversation.model == .reasoner ? .regular.tint(.blue).interactive() : .regular.interactive(), in: .capsule)
                            }
                            
                            Button {} label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "globe")
                                    Text("搜索")
                                }.font(.system(size: 14, weight: .medium)).padding(.horizontal, 12).padding(.vertical, 8)
                                .glassEffect(.regular.interactive(), in: .capsule)
                            }
                            
                            Spacer()
                            
                            Menu {
                                PhotosPicker(selection: $photoItem, matching: .images) { Label("上传图片", systemImage: "photo") }
                                Button { showFileImporter = true } label: { Label("读取文档", systemImage: "doc.text") }
                            } label: {
                                Image(systemName: "plus").font(.system(size: 20)).frame(width: 36, height: 36)
                                    .glassEffect(.regular.interactive(), in: .circle)
                            }
                            
                            if input.isEmpty && selectedImage == nil {
                                Button {
                                    if speech.isRecording { speech.stopRecording() } else { speech.startRecording() }
                                } label: {
                                    Image(systemName: "waveform").font(.system(size: 20)).frame(width: 36, height: 36)
                                        .glassEffect(.regular.tint(speech.isRecording ? .red : .clear).interactive(), in: .circle)
                                }
                            } else {
                                Button {
                                    var b64: String? = nil
                                    if let img = selectedImage { b64 = img.jpegData(compressionQuality: 0.5)?.base64EncodedString() }
                                    viewModel.send(input, imageBase64: b64, useWebSearch: false)
                                    input = ""; selectedImage = nil
                                } label: {
                                    Image(systemName: "arrow.up").font(.system(size: 18, weight: .bold)).frame(width: 36, height: 36)
                                        .glassEffect(.regular.tint(.blue).interactive(), in: .circle)
                                }
                            }
                        }
                    }
                }
                .padding(16)
                .glassEffect(.regular, in: .rect(cornerRadius: 26))
                .padding(.horizontal, 16)
                
                Text("回答由 AI 生成，仅供参考").font(.system(size: 10)).foregroundStyle(.tertiary).padding(.bottom, 8)
            }
        }
        .onChange(of: photoItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self), let uiImg = UIImage(data: data) { selectedImage = uiImg }
            }
        }
        .onChange(of: speech.transcribedText) { _, newText in if !newText.isEmpty { input = newText } }
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.pdf, .plainText]) { result in
            if let url = try? result.get(), url.startAccessingSecurityScopedResource() {
                defer { url.stopAccessingSecurityScopedResource() }
                if url.pathExtension.lowercased() == "pdf", let doc = PDFDocument(url: url) { viewModel.loadDocument(text: doc.string ?? ""); viewModel.isRagEnabled = true }
                else if let text = try? String(contentsOf: url) { viewModel.loadDocument(text: text); viewModel.isRagEnabled = true }
            }
        }
        .alert("角色设定", isPresented: $showPromptDialog) { TextField("输入指令", text: $tempPrompt, axis: .vertical); Button("保存") { viewModel.conversation.systemPrompt = tempPrompt } }
        .alert("发起辩论", isPresented: $showAutoGenDialog) { TextField("输入辩论话题", text: $autoGenTopic); Button("开始") { viewModel.startAutoGen(topic: autoGenTopic); autoGenTopic = "" } }
    }
}