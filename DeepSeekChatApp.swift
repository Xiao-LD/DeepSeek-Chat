import SwiftUI

@main
struct DeepSeekChatApp: App {
    @AppStorage("appTheme") private var appTheme: Int = 0
    
    var body: some Scene {
        WindowGroup {
            ConversationListView()
                .preferredColorScheme(appTheme == 1 ? .light : (appTheme == 2 ? .dark : nil))
                // 🔥 删除全局 accentColorHex 读取，强制使用系统原生的黑白高对比度
                .tint(.primary)
        }
    }
}