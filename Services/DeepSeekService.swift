import Foundation

final class DeepSeekService {

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

        AsyncThrowingStream { continuation in

            let task = Task {
                do {
                    guard let apiKey, !apiKey.isEmpty else {
                        throw DeepSeekError.apiKeyMissing
                    }

                    guard let url = URL(
                        string: baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                            + "/chat/completions"
                    ) else { throw DeepSeekError.invalidURL }

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

continuation.onTermination = { @Sendable _ in task.cancel() }
        }
    }
}