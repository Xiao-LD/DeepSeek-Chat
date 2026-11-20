import SwiftUI

// 1. 自适应系统主题的全局背景
struct GlassBackground: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        if colorScheme == .dark {
            LinearGradient(
                colors: [Color.black, Color(red: 0.08, green: 0.08, blue: 0.15)],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()
        } else {
            LinearGradient(
                colors: [Color(white: 0.95), Color(red: 0.9, green: 0.92, blue: 0.98)],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()
        }
    }
}

// 2. 通用液态玻璃按钮样式
struct GlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(10)
            .background(.ultraThinMaterial)
            .clipShape(Circle())
            .overlay(
                Circle().stroke(Color.primary.opacity(0.1), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.15), radius: configuration.isPressed ? 2 : 8, x: 0, y: configuration.isPressed ? 1 : 4)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

struct ConversationListView: View {
    @State private var conversations: [Conversation] = []
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ZStack {
                GlassBackground()

                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(conversations) { conv in
                            NavigationLink(destination: ChatView(conversation: conv)) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(conv.title)
                                            .font(.headline)
                                            .foregroundStyle(.primary)
                                        Text(conv.updatedAt.formatted(date: .abbreviated, time: .shortened))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.tertiary)
                                }
                                .padding()
                                // 列表行的液态玻璃背景
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                                )
                                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    StorageManager.shared.delete(id: conv.id)
                                    reload()
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("对话")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(.primary)
                    }
                    .buttonStyle(GlassButtonStyle())
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
                            .foregroundStyle(.primary)
                    }
                    .buttonStyle(GlassButtonStyle())
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .onAppear(perform: reload)
            .toolbarBackground(.hidden, for: .navigationBar) // 隐藏系统原生导航栏背景，露出我们的渐变
        }
    }

    private func reload() {
        conversations = StorageManager.shared.loadAll()
    }
}

// 3. 重构设置界面，抛弃 Form，采用自适应的玻璃卡片
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var apiKey = ""
    @State private var baseURL = "https://api.deepseek.com"
    @State private var saved = false

    var body: some View {
        NavigationStack {
            ZStack {
                GlassBackground()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // 玻璃卡片容器
                        VStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("API Key")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                SecureField("sk-...", text: $apiKey)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .padding(12)
                                    .background(Color.primary.opacity(0.05))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Base URL")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                TextField("https://api.deepseek.com", text: $baseURL)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .padding(12)
                                    .background(Color.primary.opacity(0.05))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                        .padding(20)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.primary.opacity(0.1), lineWidth: 1))
                        
                        // 液态玻璃保存按钮
                        Button {
                            KeychainHelper.shared.save(
                                apiKey, service: "DeepSeekChat", account: "apiKey"
                            )
                            UserDefaults.standard.set(baseURL, forKey: "apiBaseURL")
                            saved = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                saved = false
                            }
                        } label: {
                            Text(saved ? "已保存" : "保存配置")
                                .font(.headline)
                                .foregroundStyle(saved ? .green : .blue)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.blue.opacity(saved ? 0 : 0.3), lineWidth: 1))
                                .shadow(color: Color.blue.opacity(saved ? 0 : 0.2), radius: 10, x: 0, y: 5)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 20)
                    }
                    .padding(.top, 20)
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.primary.opacity(0.1), lineWidth: 1))
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
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