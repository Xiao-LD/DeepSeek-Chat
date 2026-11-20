import SwiftUI

// 提取一个全局通用的炫酷渐变背景，方便重复使用
struct GlassBackground: View {
    var body: some View {
        LinearGradient(
            colors: [Color.black, Color(red: 0.08, green: 0.08, blue: 0.15)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

struct ConversationListView: View {
    @State private var conversations: [Conversation] = []
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ZStack {
                GlassBackground()

                List {
                    ForEach(conversations) { conv in
                        NavigationLink(conv.title) {
                            ChatView(conversation: conv)
                        }
                        // 列表每一行透明，露出背景
                        .listRowBackground(Color.clear)
                        .listRowSeparatorTint(Color.white.opacity(0.1))
                        .foregroundStyle(.white)
                    }
                    .onDelete { indexSet in
                        for i in indexSet {
                            StorageManager.shared.delete(id: conversations[i].id)
                        }
                        reload()
                    }
                }
                .scrollContentBackground(.hidden) // 隐藏系统默认列表背景
                .listStyle(.plain)
            }
            .navigationTitle("对话")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(.white)
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        let new = Conversation(
                            id: UUID(), title: "新对话", messages: [],
                            systemPrompt: "", model: .chat, temperature: 0.7,
                            createdAt: Date(), updatedAt: Date()
                        )
                        StorageManager.shared.save(new)
                        reload()
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .foregroundStyle(.white)
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .onAppear(perform: reload)
            // 让主界面的顶部导航栏也变成毛玻璃
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            // 让状态栏文字变成白色
            .preferredColorScheme(.dark)
        }
    }

    private func reload() {
        conversations = StorageManager.shared.loadAll()
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var apiKey = ""
    @State private var baseURL = "https://api.deepseek.com"
    @State private var saved = false

    var body: some View {
        NavigationStack {
            ZStack {
                GlassBackground()

                Form {
                    Section {
                        SecureField("DeepSeek API Key", text: $apiKey)
                            .foregroundStyle(.white)
                        TextField("Base URL", text: $baseURL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .foregroundStyle(.white)
                    } header: {
                        Text("API 配置")
                    }
                    .listRowBackground(Color.white.opacity(0.05)) // 设置项的半透明底色

                    Section {
                        Button("保存 API Key") {
                            KeychainHelper.shared.save(
                                apiKey, service: "DeepSeekChat", account: "apiKey"
                            )
                            UserDefaults.standard.set(baseURL, forKey: "apiBaseURL")
                            saved = true
                        }
                        .foregroundStyle(.blue)
                    }
                    .listRowBackground(Color.white.opacity(0.05))

                    if saved {
                        Text("已保存")
                            .foregroundStyle(.green)
                            .font(.caption)
                            .listRowBackground(Color.clear)
                    }
                }
                .scrollContentBackground(.hidden) // 隐藏设置界面的默认背景
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .preferredColorScheme(.dark)
            .onAppear {
                apiKey = KeychainHelper.shared.read(
                    service: "DeepSeekChat", account: "apiKey"
                ) ?? ""
                baseURL = UserDefaults.standard.string(
                    forKey: "apiBaseURL"
                ) ?? "https://api.deepseek.com"
            }
        }
    }
}