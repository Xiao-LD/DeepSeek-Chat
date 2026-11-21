import SwiftUI

struct GlassBackground: View {
    @Environment(\.colorScheme) var colorScheme
    var body: some View {
        if colorScheme == .dark {
            LinearGradient(colors: [Color.black, Color(red: 0.08, green: 0.08, blue: 0.15)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
        } else {
            LinearGradient(colors: [Color(red: 0.98, green: 0.98, blue: 1.0), Color(red: 0.92, green: 0.94, blue: 0.98)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
        }
    }
}

struct GlassButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) var colorScheme
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(10).background { if colorScheme == .dark { Circle().fill(.ultraThinMaterial) } else { Circle().fill(Color.white) } }
            .clipShape(Circle()).overlay(Circle().stroke(Color.primary.opacity(colorScheme == .dark ? 0.15 : 0.05), lineWidth: 1))
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.2 : 0.05), radius: configuration.isPressed ? 2 : 6, x: 0, y: configuration.isPressed ? 1 : 3)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0).animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

struct ConversationListView: View {
    @State private var conversations: [Conversation] = []
    @State private var showSettings = false
    @Environment(\.colorScheme) var colorScheme
    
    @State private var searchText = ""
    @State private var renamingConversation: Conversation?
    @State private var newTitle = ""
    @State private var exportingConversation: Conversation?

    var filteredConversations: [Conversation] {
        if searchText.isEmpty { return conversations }
        return conversations.filter { $0.title.localizedCaseInsensitiveContains(searchText) || $0.messages.contains { $0.content.localizedCaseInsensitiveContains(searchText) } }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                GlassBackground()
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredConversations) { conv in
                            NavigationLink(destination: ChatView(conversation: conv)) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(conv.title).font(.headline).foregroundStyle(.primary)
                                        Text(conv.updatedAt.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold)).foregroundStyle(.tertiary)
                                }
                                .padding().background { if colorScheme == .dark { RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial) } else { RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.8)) } }
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.primary.opacity(0.05), lineWidth: 1))
                                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.1 : 0.03), radius: 5, x: 0, y: 2)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button { renamingConversation = conv; newTitle = conv.title } label: { Label("重命名", systemImage: "pencil") }
                                Button { exportingConversation = conv } label: { Label("导出 Markdown", systemImage: "square.and.arrow.up") }
                                Button(role: .destructive) { StorageManager.shared.delete(id: conv.id); reload() } label: { Label("删除", systemImage: "trash") }
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("对话").searchable(text: $searchText, prompt: "搜索对话")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button { showSettings = true } label: { Image(systemName: "gearshape.fill").foregroundStyle(.primary) }.buttonStyle(GlassButtonStyle()) }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        let new = Conversation(id: UUID(), title: "新对话", messages: [], systemPrompt: "", model: .chat, temperature: 0.7, createdAt: Date(), updatedAt: Date())
                        StorageManager.shared.save(new); reload()
                    } label: { Image(systemName: "square.and.pencil").foregroundStyle(.primary) }.buttonStyle(GlassButtonStyle())
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .onAppear(perform: reload)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar).toolbarBackground(.visible, for: .navigationBar)
            .alert("重命名对话", isPresented: Binding(get: { renamingConversation != nil }, set: { if !$0 { renamingConversation = nil } })) {
                TextField("输入新标题", text: $newTitle)
                Button("取消", role: .cancel) { renamingConversation = nil }
                Button("保存") {
                    if var conv = renamingConversation { conv.title = newTitle; StorageManager.shared.save(conv); reload() }
                    renamingConversation = nil
                }
            }
            // 导出功能
            .sheet(item: $exportingConversation) { conv in
                let mdText = conv.messages.map { "### \($0.role == .user ? "User" : "AI")\n\($0.content)\n" }.joined(separator: "\n---\n")
                ShareSheet(activityItems: [mdText])
            }
        }
    }
    private func reload() { conversations = StorageManager.shared.loadAll() }
}

// 用于导出的系统分享视图
struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// 设置界面
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var apiKey = ""
    @State private var baseURL = "https://api.deepseek.com"
    @State private var tavilyKey = ""
    @State private var saved = false
    
    @AppStorage("appTheme") private var appTheme: Int = 0
    @AppStorage("totalPromptTokens") private var totalPromptTokens: Int = 0
    @AppStorage("totalCompletionTokens") private var totalCompletionTokens: Int = 0

    var body: some View {
        NavigationStack {
            ZStack {
                GlassBackground()
                ScrollView {
                    VStack(spacing: 20) {
                        // 外观
                        VStack(alignment: .leading, spacing: 10) {
                            Text("外观主题").font(.caption).foregroundStyle(.secondary)
                            Picker("外观", selection: $appTheme) {
                                Text("跟随系统").tag(0); Text("浅色").tag(1); Text("深色").tag(2)
                            }.pickerStyle(.segmented)
                        }
                        .padding(20).background { RoundedRectangle(cornerRadius: 20).fill(colorScheme == .dark ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.white.opacity(0.8))) }
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous)).overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.primary.opacity(0.05), lineWidth: 1))

                        // 数据统计
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Token 用量统计").font(.caption).foregroundStyle(.secondary)
                            HStack {
                                Text("输入: \(totalPromptTokens)")
                                Spacer()
                                Text("输出: \(totalCompletionTokens)")
                            }.