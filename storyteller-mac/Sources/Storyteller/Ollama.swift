import Foundation

struct OllamaError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

enum Ollama {
    static let base = URL(string: ProcessInfo.processInfo.environment["OLLAMA_URL"] ?? "http://127.0.0.1:11434")!

    /// Streams text tokens from Ollama's /api/chat.
    static func stream(_ messages: [ChatMessage], settings s: GenSettings) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { cont in
            let task = Task {
                do {
                    var req = URLRequest(url: base.appending(path: "api/chat"))
                    req.httpMethod = "POST"
                    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    req.timeoutInterval = 300
                    let body: [String: Any] = [
                        "model": s.model,
                        "stream": true,
                        "keep_alive": "30m",
                        "messages": messages.map { ["role": $0.role, "content": $0.content] },
                        "options": [
                            "temperature": s.temperature,
                            "num_predict": s.maxTokens,
                            "num_ctx": s.contextWindow,
                            "repeat_penalty": 1.1,
                        ],
                    ]
                    req.httpBody = try JSONSerialization.data(withJSONObject: body)

                    let (bytes, resp) = try await URLSession.shared.bytes(for: req)
                    if let http = resp as? HTTPURLResponse, http.statusCode != 200 {
                        var text = ""
                        for try await line in bytes.lines { text += line }
                        throw OllamaError(message: errorText(text) ?? "Ollama returned \(http.statusCode)")
                    }
                    for try await line in bytes.lines {
                        guard let data = line.data(using: .utf8),
                              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
                        if let e = json["error"] as? String { throw OllamaError(message: e) }
                        if let msg = json["message"] as? [String: Any], let c = msg["content"] as? String, !c.isEmpty {
                            cont.yield(c)
                        }
                    }
                    cont.finish()
                } catch {
                    cont.finish(throwing: error)
                }
            }
            cont.onTermination = { _ in task.cancel() }
        }
    }

    static func models() async -> [String] {
        guard let (data, _) = try? await URLSession.shared.data(from: base.appending(path: "api/tags")),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let models = json["models"] as? [[String: Any]] else { return [] }
        return models.compactMap { $0["name"] as? String }
    }

    /// Size and memory-per-token of a model, for RAM estimates.
    static func modelInfo(_ name: String) async -> ModelInfo? {
        var req = URLRequest(url: base.appending(path: "api/show"))
        req.httpMethod = "POST"
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["model": name])
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let info = json["model_info"] as? [String: Any] else { return nil }
        // Keys are prefixed with the architecture, e.g. "llama.block_count".
        func int(_ suffix: String) -> Int? {
            info.first { $0.key.hasSuffix(suffix) }.flatMap { ($0.value as? NSNumber)?.intValue }
        }
        guard let layers = int(".block_count"), let embed = int(".embedding_length"),
              let heads = int(".attention.head_count") else { return nil }
        let kvHeads = int(".attention.head_count_kv") ?? heads
        let keyLen = int(".attention.key_length") ?? embed / heads
        let valLen = int(".attention.value_length") ?? keyLen
        // f16 key + value cache for every layer.
        let kvPerToken = Int64(layers * kvHeads * (keyLen + valLen) * 2)

        guard let (tagData, _) = try? await URLSession.shared.data(from: base.appending(path: "api/tags")),
              let tags = try? JSONSerialization.jsonObject(with: tagData) as? [String: Any],
              let models = tags["models"] as? [[String: Any]],
              let size = models.first(where: { $0["name"] as? String == name })?["size"] as? NSNumber else { return nil }
        return ModelInfo(fileBytes: size.int64Value, kvBytesPerToken: kvPerToken,
                         maxContext: int(".context_length") ?? 8192)
    }

    /// Models currently loaded in memory, with Ollama's measured size.
    static func loaded() async -> [String: LoadedModel] {
        guard let (data, _) = try? await URLSession.shared.data(from: base.appending(path: "api/ps")),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let models = json["models"] as? [[String: Any]] else { return [:] }
        var out: [String: LoadedModel] = [:]
        for m in models {
            guard let name = m["name"] as? String, let size = m["size"] as? NSNumber else { continue }
            out[name] = LoadedModel(bytes: size.int64Value, context: (m["context_length"] as? NSNumber)?.intValue)
        }
        return out
    }

    static func describe(_ error: Error) -> String {
        if let e = error as? URLError, e.code == .cannotConnectToHost || e.code == .cannotFindHost {
            return "Could not reach Ollama at \(base.absoluteString). Is it running?"
        }
        return error.localizedDescription
    }

    private static func errorText(_ body: String) -> String? {
        guard let data = body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return body.isEmpty ? nil : body }
        return json["error"] as? String
    }
}

struct ModelInfo {
    let fileBytes: Int64
    let kvBytesPerToken: Int64
    let maxContext: Int

    /// Model weights + context cache + ~100 MB of working buffers.
    func ramBytes(context: Int) -> Int64 {
        fileBytes + kvBytesPerToken * Int64(context) + 100_000_000
    }
}

struct LoadedModel {
    let bytes: Int64
    let context: Int?
}

extension Int64 {
    var gigabytes: String { String(format: "%.1f GB", Double(self) / 1_000_000_000) }
}
