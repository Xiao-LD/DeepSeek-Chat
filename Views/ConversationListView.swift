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
                // 🔥 使用 safeAreaInset 占位，这样列表滑上去会被顶部栏盖住，绝不会重叠
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
                    // 🔥 给顶部栏加上高斯模糊底，滑动时直接虚化文字
                    .background((colorScheme == .dark ? Color.black : Color.white).opacity(0.95).blur(radius: 10))
                    .overlay(alignment: .bottom) {
                        // 底部加一条渐隐线，过渡更平滑
                        LinearGradient(colors: [(colorScheme == .dark ? Color.black : Color.white).opacity(0), (colorScheme == .dark ? Color.black : Color.white)], startPoint: .top, endPoint: .bottom)
                            .frame(height: 20).offset(y: 20)
                    }
                }
                
                // 底部搜索框
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
            .sheet(isPresented: $showSettings) { SettingsView() }
            .onAppear(perform: reload)
            .alert("重命名", isPresented: Binding(get: { renamingConversation != nil }, set: { if !$0 { renamingConversation = nil } })) {
                TextField("新标题", text: $newTitle)
                Button("取消", role: .cancel) { renamingConversation = nil }
                Button("保存") { if var conv = renamingConversation { conv.title = newTitle; StorageManager.shared.save(conv); reload() }; renamingConversation = nil }
            }
            .sheet(isPresented: $showShareSheet) { if let img = shareImage { ShareSheet(activityItems: [img]) } }
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

// 以下 ShareSheet / SettingsView / Color扩展 保持不变，直接沿用你上次提交的即可。