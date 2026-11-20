import SwiftUI

struct ConversationListView: View {
    @State private var conversations: [Conversation] = []
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(conversations) { conv in
                    NavigationLink(conv.title) {
                        ChatView(conversation: conv)
                    }
                }
                .onDelete { indexSet in
                    for i in indexSet {
                        StorageManager.shared.delete(id: conversations[i].id)
                    }
                    reload()
                }
            }
            .navigationTitle("对话")
            .toolbar {
                Button {
                    let new = Conversation(
                        id: UUID(), title: "新对话", messages: [],
                        systemPrompt: "", model: .chat, temperature: 0.7,
                        createdAt: Date(), updatedAt: Date()
                    )
                    StorageManager.shared.save(new)
                    reload()
                } label: { Image(systemName: "plus") }

                Button { showSettings = true } label: {
                    Image(systemName: "gearshape")
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .onAppear(perform: reload)
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
            Form {
                Section("API 配置") {
                    SecureField("DeepSeek API Key", text: $apiKey)
                    TextField("Base URL", text: $baseURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section {
                    Button("保存 API Key") {
                        KeychainHelper.shared.save(
                            apiKey, service: "DeepSeekChat", account: "apiKey"
                        )
                        UserDefaults.standard.set(baseURL, forKey: "apiBaseURL")
                        saved = true
                    }
                }

                if saved {
                    Text("已保存").foregroundStyle(.green).font(.caption)
                }
            }
            .navigationTitle("设置")
            .toolbar {
                Button("完成") { dismiss() }
            }
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