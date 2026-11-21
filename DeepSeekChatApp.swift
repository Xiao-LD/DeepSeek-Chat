import SwiftUI

@main
struct DeepSeekChatApp: App {
    // 监听主题设置：0 = 跟随系统, 1 = 浅色, 2 = 深色
    @AppStorage("appTheme") private var appTheme: Int = 0
    
    var body: some Scene {
        WindowGroup {
            ConversationListView()
                .preferredColorScheme(
                    appTheme == 1 ? .light : (appTheme == 2 ? .dark : nil)
                )
        }
    }
}