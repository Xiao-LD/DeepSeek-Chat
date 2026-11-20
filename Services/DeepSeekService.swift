import Foundation

// 声明 @unchecked Sendable，告诉编译器我们自己保证并发安全
final class DeepSeekService: @unchecked Sendable {

    var baseURL: String {
        get { UserDefaults.standard.string(forKey: "apiBaseURL") ?? "https://api.deepseek.com" }
        set { UserDefaults.standard.set(newValue, forKey: "apiBaseURL") }
    }

    var apiKey: String? {
        KeychainHelper.shared.read(service: "DeepSeekChat", account: "apiKey")
    }

    func streamCompletion(
        messages: [APIMessage],
        model: DeepSeekModel,
        temperature: Double
    ) -> AsyncThrowingStream<StreamEvent, Error> {
        
        // 1. 提前把需要的变量提取为局部常量，防止 Task 内部捕获 self
        let base = self.baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let key = self.apiKey
        
        return AsyncThrowingStream { continuation in
            // 2. 使用 Task.detached 切断对外部 actor 隔离的继承
            let task = Task.detached {
                do {
                    guard let apiKey = key, !apiKey.isEmpty else {
                        throw DeepSeekError.apiKeyMissing
                    }

                    guard let url = URL(string: base + "/chat/completions") else {
                        throw DeepSeekError.invalidURL
                    }

                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                    request.timeoutInterval = 120

                    let body = ChatCompletionRequest(
                        model: model.rawValue,
                        messages: messages,
                        temperature: temperature,
                        stream: true,
                        maxTokens: nil
                    )
                    request.httpBody = try JSONEncoder().encode(body)

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)

                    guard let http = response as? HTTPURLResponse else {
                        throw DeepSeekError.invalidResponse
                    }

                    guard http.statusCode == 200 else {
                        var errorBody = ""
                        for try await line in bytes.lines {
                            errorBody.append(line)
                        }
                        throw DeepSeekError.httpError(
                            statusCode: http.statusCode,
                            body: errorBody
                        )
                    }

                    for try await line in bytes.lines {
                        guard line.hasPrefix("data:") else { continue }
                        let payload = line.dropFirst(5)
                            .trimmingCharacters(in: .whitespaces)

                        if payload == "[DONE]" {
                            continuation.yield(.finished(usage: nil))
                            continuation.finish()
                            return
                        }

                        guard let data = payload.data(using: .utf8),
                              let chunk = try? JSONDecoder().decode(
                                  ChatCompletionChunk.self,
                                  from: data
                              )
                        else { continue }

                        for choice in chunk.choices ?? [] {
                            if let r = choice.delta.reasoningContent, !r.isEmpty {
                                continuation.yield(.reasoningDelta(r))
                            }
                            if let c = choice.delta.content, !c.isEmpty {
                                continuation.yield(.contentDelta(c))
                            }
                            if choice.finishReason != nil {
                                continuation.yield(.finished(usage: chunk.usage))
                                continuation.finish()
                                return
                            }
                        }
                    }

                    continuation.finish()

                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            // 3. 标准的 onTermination 取消逻辑
            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }
}