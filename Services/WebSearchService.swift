import Foundation

class WebSearchService {
    static let shared = WebSearchService()
    
    func search(query: String) async throws -> String {
        // 从 UserDefaults 获取用户在设置里填写的 Tavily Key
        guard let apiKey = UserDefaults.standard.string(forKey: "tavilyApiKey"), !apiKey.isEmpty else {
            throw NSError(domain: "Search", code: 401, userInfo: [NSLocalizedDescriptionKey: "请先在设置中配置 Tavily 搜索 API Key"])
        }
        
        let url = URL(string: "https://api.tavily.com/search")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "api_key": apiKey,
            "query": query,
            "search_depth": "basic",
            "include_answer": false,
            "max_results": 3
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let results = json["results"] as? [[String: Any]] {
            
            var searchContext = "以下是联网搜索到的最新背景信息，请结合这些信息回答我的问题：\n\n"
            for res in results {
                if let title = res["title"] as? String, let content = res["content"] as? String {
                    searchContext += "- \(title): \(content)\n"
                }
            }
            return searchContext
        }
        
        return ""
    }
}