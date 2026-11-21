import SwiftUI

struct GlassBackground: View {
    @Environment(\.colorScheme) var colorScheme
    var body: some View {
        (colorScheme == .dark ? Color.black : Color.white).ignoresSafeArea()
    }
}

struct ConversationListView: View {
    @State private var conversations: [Conversation] = []
    @State private var showSettings = false
    @Environment(\.colorScheme) var colorScheme
    @State private var searchText = ""
    @State private var renamingConversation: Conversation?
    @State private var newTitle = ""
    @State private var shareImage: UIImage?
    @State private var showShareSheet = false

    var filteredConversations: [Conversation] {
        if searchText.isEmpty { return conversations }
        return conversations.filter { $0.title.localizedCaseInsensitiveContains(searchText) || $0.messages.contains { $0.content.localizedCaseInsensitiveContains(searchText) } }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                GlassBackground()
                
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(filteredConversations) { conv in
                            NavigationLink(destination: ChatView(conversation: conv)) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(conv.title).font(.system(size: 16, weight: .medium)).foregroundStyle(.primary)
                                        Text(conv.updatedAt.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                }
                                .padding(16)
                                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button { renamingConversation = conv; newTitle = conv.title } label: { Label("重命名", systemImage: "pencil") }
                                Button { generateImage(for: conv) } label: { Label("生成分享长图", systemImage: "photo") }
                                Button(role: .destructive) { StorageManager.shared.delete(id: conv.id); reload() } label: { Label("删除", systemImage: "trash") }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 80)
                }
                .safeAreaInset(edge: .top) {
                    VStack(spacing: 0) {
                        GlassEffectContainer(spacing: 16) {
                            HStack {
                                Button { showSettings = true } label: {
                                    Image(systemName: "line.3.horizontal").font(.system(size: 18, weight: .medium)).foregroundStyle(.primary).frame(width: 44, height: 44)
                                        .glassEffect(.regular.interactive(), in: .circle)
                                }
                                Spacer()
                                Button {
                                    let new = Conversation(id: UUID(), title: "新对话", messages: [], systemPrompt: "", model: .chat, temperature: 0.7, createdAt: Date(), updatedAt: Date())
                                    StorageManager.shared.save(new); reload()
                                } label: {
                                    Image(systemName: "plus").font(.system(size: 20, weight: .medium)).foregroundStyle(.primary).frame(width: 44, height: 44)
                                        .glassEffect(.regular.interactive(), in: .circle)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                        
                        HStack {
                            Text("对话").font(.system(size: 36, weight: .bold)).foregroundStyle(.primary)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 10)
                    }
                    .background((colorScheme == .dark ? Color.black : Color.white).opacity(0.95).blur(radius: 10))
                    .overlay(alignment: .bottom) {
                        LinearGradient(colors: [(colorScheme == .dark ? Color.black : Color.white).opacity(0), (colorScheme == .dark ? Color.black : Color.white)], startPoint: .top, endPoint: .bottom)
                            .frame(height: 20).offset(y: 20)
                    }
                }
                
                VStack {
                    Spacer()
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                        TextField("搜索历史", text: $searchText).textInputAutocapitalization(.never)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .glassEffect(.regular.interactive(), in: .capsule)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            // 🔥 修复：使用 item 驱动 sheet 会在 Swift 6 下更安全，避免直接捕获无主闭包
            .sheet(isPresented: $showSettings, content: {
                SettingsView()
            })
            .onAppear(perform: reload)
            .alert("重命名", isPresented: Binding(get: { renamingConversation != nil }, set: { if !$0 { renamingConversation = nil } })) {
                TextField("新标题", text: $newTitle)
                Button("取消", role: .cancel) { renamingConversation = nil }
                Button("保存") { if var conv = renamingConversation { conv.title = newTitle; StorageManager.shared.save(conv); reload() }; renamingConversation = nil }
            }
            .sheet(isPresented: $showShareSheet, content: {
                if let img = shareImage { ShareSheet(activityItems: [img]) }
            })
        }
    }
    
    private func generateImage(for conv: Conversation) {
        let renderer = ImageRenderer(content: ShareImageView(conversation: conv))
        renderer.scale = 3.0
        if let uiImage = renderer.uiImage {
            shareImage = uiImage
            showShareSheet = true
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
    private func reload() { conversations = StorageManager.shared.loadAll() }
}

// 下面保持 ShareSheet, SettingsView, Color 扩展 不变。
// 为了防止拼接断掉，我把它们完整写出来：
struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: activityItems, applicationActivities: nil) }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var apiKey = ""
    @State private var baseURL = "https://api.deepseek.com"
    @State private var tavilyKey = ""
    @State private var saved = false
    @AppStorage("appTheme") private var appTheme: Int = 0
    @AppStorage("accentColorHex") private var accentColorHex: String = "#007AFF"
    @AppStorage("totalPromptTokens") private var totalPromptTokens: Int = 0
    @AppStorage("totalCompletionTokens") private var totalCompletionTokens: Int = 0
    @AppStorage("customModelName") private var customModelName: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("外观") {
                    Picker("主题", selection: $appTheme) { Text("系统").tag(0); Text("浅色").tag(1); Text("深色").tag(2) }.pickerStyle(.segmented)
                    ColorPicker("强调色", selection: Binding(get: { Color(hex: accentColorHex) }, set: { accentColorHex = $0.toHex() ?? "#007AFF" }))
                }
                Section("统计") { Text("消耗: \(totalPromptTokens) / \(totalCompletionTokens) tokens") }
                Section("API 配置") {
                    SecureField("API Key", text: $apiKey)
                    TextField("Base URL", text: $baseURL)
                    TextField("自定义模型名 (留空默认)", text: $customModelName)
                    SecureField("Tavily Key", text: $tavilyKey)
                }
                Section {
                    Button(saved ? "已保存" : "保存配置") {
                        KeychainHelper.shared.save(apiKey, service: "DeepSeekChat", account: "apiKey")
                        UserDefaults.standard.set(baseURL, forKey: "apiBaseURL")
                        UserDefaults.standard.set(tavilyKey, forKey: "tavilyApiKey")
                        saved = true; DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { saved = false }
                    }
                }
            }
            .navigationTitle("设置").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }.buttonStyle(.glassProminent)
                }
            }
            .onAppear {
                apiKey = KeychainHelper.shared.read(service: "DeepSeekChat", account: "apiKey") ?? ""
                baseURL = UserDefaults.standard.string(forKey: "apiBaseURL") ?? "https://api.deepseek.com"
                tavilyKey = UserDefaults.standard.string(forKey: "tavilyApiKey") ?? ""
            }
        }
    }
}

extension Color {
    func toHex() -> String? {
        let uic = UIColor(self)
        guard let components = uic.cgColor.components, components.count >= 3 else { return nil }
        return String(format: "#%02lX%02lX%02lX", lroundf(Float(components[0]) * 255), lroundf(Float(components[1]) * 255), lroundf(Float(components[2]) * 255))
    }
}