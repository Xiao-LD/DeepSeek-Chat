import SwiftUI

@main
struct DeepSeekChatApp: App {
    @AppStorage("appTheme") private var appTheme: Int = 0
    @AppStorage("accentColorHex") private var accentColorHex: String = "#007AFF" // 默认蓝色
    
    var body: some Scene {
        WindowGroup {
            ConversationListView()
                .preferredColorScheme(appTheme == 1 ? .light : (appTheme == 2 ? .dark : nil))
                .tint(Color(hex: accentColorHex)) // 全局应用主题色
        }
    }
}