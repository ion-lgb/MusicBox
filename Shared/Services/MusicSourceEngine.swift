import Foundation
@preconcurrency import JavaScriptCore

/// 音源引擎 - 使用 JavaScriptCore 加载和执行洛雪格式音源脚本
@MainActor @Observable
final class MusicSourceEngine {
    private var jsContext: JSContext?
    private(set) var sources: [MusicSourceConfig] = []
    private(set) var isLoaded = false
    private(set) var errorMessage: String?

    private let storage = MusicSourceStorage()

    init() {
        loadSavedSources()
    }

    // MARK: - 音源管理

    /// 从订阅 URL 下载并添加音源
    func addSourceFromURL(_ urlString: String) async throws {
        guard let url = URL(string: urlString) else {
            throw MusicSourceError.invalidURL
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        guard let scriptContent = String(data: data, encoding: .utf8) else {
            throw MusicSourceError.invalidScript
        }

        let config = try parseScriptConfig(scriptContent, subscriptionUrl: urlString)
        try storage.saveSource(config)
        sources.append(config)
        try setupJSContext()
    }

    /// 更新已有音源（从订阅地址重新下载）
    func updateSource(_ source: MusicSourceConfig) async throws {
        guard let urlString = source.subscriptionUrl,
              let url = URL(string: urlString) else {
            throw MusicSourceError.noSubscriptionURL
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        guard let scriptContent = String(data: data, encoding: .utf8) else {
            throw MusicSourceError.invalidScript
        }

        var updated = try parseScriptConfig(scriptContent, subscriptionUrl: urlString)
        updated = MusicSourceConfig(
            name: updated.name.isEmpty ? source.name : updated.name,
            description: updated.description,
            version: updated.version,
            author: updated.author,
            platforms: updated.platforms,
            scriptContent: scriptContent,
            subscriptionUrl: urlString
        )

        try storage.deleteSource(id: source.id)
        try storage.saveSource(updated)

        if let index = sources.firstIndex(where: { $0.id == source.id }) {
            sources[index] = updated
        }
        try setupJSContext()
    }

    /// 删除音源
    func removeSource(_ source: MusicSourceConfig) throws {
        try storage.deleteSource(id: source.id)
        sources.removeAll { $0.id == source.id }
        try setupJSContext()
    }

    // MARK: - 搜索

    /// 聚合搜索
    func search(keyword: String, platform: MusicPlatform? = nil) async throws -> [Song] {
        guard isLoaded, let context = jsContext else {
            throw MusicSourceError.engineNotReady
        }

        return try await withCheckedThrowingContinuation { continuation in
            let callback: @convention(block) (JSValue?) -> Void = { result in
                guard let result = result, !result.isUndefined, !result.isNull else {
                    continuation.resume(returning: [])
                    return
                }
                let songs = self.parseSongsFromJS(result)
                continuation.resume(returning: songs)
            }

            let errorCallback: @convention(block) (JSValue?) -> Void = { error in
                let msg = error?.toString() ?? "Unknown error"
                continuation.resume(throwing: MusicSourceError.scriptError(msg))
            }

            context.setObject(callback, forKeyedSubscript: "__searchCallback" as NSString)
            context.setObject(errorCallback, forKeyedSubscript: "__searchErrorCallback" as NSString)

            let platformArg = platform?.rawValue ?? "all"
            let script = """
            (async function() {
                try {
                    const results = await __musicSource.search('\(keyword.replacingOccurrences(of: "'", with: "\\'"))', '\(platformArg)');
                    __searchCallback(results);
                } catch(e) {
                    __searchErrorCallback(e.message || String(e));
                }
            })();
            """
            context.evaluateScript(script)
        }
    }

    /// 获取歌曲播放链接
    func getSongUrl(song: Song) async throws -> String {
        guard isLoaded, let context = jsContext else {
            throw MusicSourceError.engineNotReady
        }

        return try await withCheckedThrowingContinuation { continuation in
            let callback: @convention(block) (JSValue?) -> Void = { result in
                guard let url = result?.toString(), !url.isEmpty, url != "undefined" else {
                    continuation.resume(throwing: MusicSourceError.noPlayUrl)
                    return
                }
                continuation.resume(returning: url)
            }

            let errorCallback: @convention(block) (JSValue?) -> Void = { error in
                let msg = error?.toString() ?? "Unknown error"
                continuation.resume(throwing: MusicSourceError.scriptError(msg))
            }

            context.setObject(callback, forKeyedSubscript: "__urlCallback" as NSString)
            context.setObject(errorCallback, forKeyedSubscript: "__urlErrorCallback" as NSString)

            let script = """
            (async function() {
                try {
                    const url = await __musicSource.getSongUrl('\(song.platform.rawValue)', '\(song.platformId)', 'standard');
                    __urlCallback(url);
                } catch(e) {
                    __urlErrorCallback(e.message || String(e));
                }
            })();
            """
            context.evaluateScript(script)
        }
    }

    /// 获取歌词
    func getLyric(song: Song) async throws -> String {
        guard isLoaded, let context = jsContext else {
            throw MusicSourceError.engineNotReady
        }

        return try await withCheckedThrowingContinuation { continuation in
            let callback: @convention(block) (JSValue?) -> Void = { result in
                continuation.resume(returning: result?.toString() ?? "")
            }

            let errorCallback: @convention(block) (JSValue?) -> Void = { error in
                continuation.resume(returning: "")
            }

            context.setObject(callback, forKeyedSubscript: "__lyricCallback" as NSString)
            context.setObject(errorCallback, forKeyedSubscript: "__lyricErrorCallback" as NSString)

            let script = """
            (async function() {
                try {
                    const lyric = await __musicSource.getLyric('\(song.platform.rawValue)', '\(song.platformId)');
                    __lyricCallback(lyric);
                } catch(e) {
                    __lyricErrorCallback(e.message || String(e));
                }
            })();
            """
            context.evaluateScript(script)
        }
    }

    // MARK: - 内部方法

    private func loadSavedSources() {
        sources = storage.loadSources()
        if !sources.isEmpty {
            try? setupJSContext()
        }
    }

    private func setupJSContext() throws {
        let context = JSContext()!

        // 注入 console.log
        let consoleLog: @convention(block) (JSValue) -> Void = { value in
            print("[JS]", value.toString() ?? "")
        }
        context.setObject(consoleLog, forKeyedSubscript: "log" as NSString)
        context.evaluateScript("var console = { log: log, warn: log, error: log, info: log };")

        // 注入 fetch 兼容层
        let fetchBlock: @convention(block) (String, JSValue?) -> JSValue = { urlString, options in
            let promise = JSValue(newPromiseIn: context) { resolve, reject in
                guard let url = URL(string: urlString) else {
                    reject?.call(withArguments: ["Invalid URL: \(urlString)"])
                    return
                }
                var request = URLRequest(url: url)
                request.timeoutInterval = 15

                if let opts = options, !opts.isUndefined {
                    if let method = opts.forProperty("method")?.toString() {
                        request.httpMethod = method
                    }
                    if let headers = opts.forProperty("headers"), !headers.isUndefined {
                        if let dict = headers.toDictionary() as? [String: String] {
                            for (key, value) in dict {
                                request.setValue(value, forHTTPHeaderField: key)
                            }
                        }
                    }
                    if let body = opts.forProperty("body"), !body.isUndefined {
                        request.httpBody = body.toString()?.data(using: .utf8)
                    }
                }

                URLSession.shared.dataTask(with: request) { data, response, error in
                    if let error = error {
                        reject?.call(withArguments: [error.localizedDescription])
                        return
                    }
                    guard let data = data else {
                        reject?.call(withArguments: ["No data"])
                        return
                    }
                    let text = String(data: data, encoding: .utf8) ?? ""
                    let httpResponse = response as? HTTPURLResponse
                    let status = httpResponse?.statusCode ?? 200

                    let responseObj = JSValue(object: [
                        "status": status,
                        "ok": status >= 200 && status < 300,
                        "text": text
                    ], in: context)

                    // 添加 json() 方法
                    let jsonFn: @convention(block) () -> JSValue? = {
                        return context.evaluateScript("JSON.parse('\(text.replacingOccurrences(of: "'", with: "\\'").replacingOccurrences(of: "\n", with: "\\n"))')")
                    }
                    responseObj?.setObject(jsonFn, forKeyedSubscript: "json" as NSString)

                    let textFn: @convention(block) () -> JSValue? = {
                        return JSValue(object: text, in: context)
                    }
                    responseObj?.setObject(textFn, forKeyedSubscript: "text" as NSString)

                    resolve?.call(withArguments: [responseObj as Any])
                }.resume()
            }
            return promise!
        }
        context.setObject(fetchBlock, forKeyedSubscript: "fetch" as NSString)

        // 注入 setTimeout
        let setTimeout: @convention(block) (JSValue, Int) -> Void = { callback, delay in
            let cb = callback
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(delay)) {
                cb.call(withArguments: [])
            }
        }
        context.setObject(setTimeout, forKeyedSubscript: "setTimeout" as NSString)

        // 注入音源管理对象
        context.evaluateScript("var __musicSource = {};")

        // 加载所有激活的音源脚本
        for source in sources where source.isActive {
            context.evaluateScript(source.scriptContent)
        }

        // 异常处理
        context.exceptionHandler = { _, exception in
            print("[JS Error]", exception?.toString() ?? "Unknown error")
        }

        self.jsContext = context
        self.isLoaded = true
        self.errorMessage = nil
    }

    private func parseScriptConfig(_ script: String, subscriptionUrl: String? = nil) throws -> MusicSourceConfig {
        // 尝试从脚本中提取元数据注释
        var name = "自定义音源"
        var description = ""
        var version = "1.0.0"
        var author = ""

        if let nameMatch = script.range(of: #"@name\s+(.+)"#, options: .regularExpression) {
            name = String(script[nameMatch]).replacingOccurrences(of: #"@name\s+"#, with: "", options: .regularExpression)
        }
        if let descMatch = script.range(of: #"@description\s+(.+)"#, options: .regularExpression) {
            description = String(script[descMatch]).replacingOccurrences(of: #"@description\s+"#, with: "", options: .regularExpression)
        }
        if let verMatch = script.range(of: #"@version\s+(.+)"#, options: .regularExpression) {
            version = String(script[verMatch]).replacingOccurrences(of: #"@version\s+"#, with: "", options: .regularExpression)
        }
        if let authorMatch = script.range(of: #"@author\s+(.+)"#, options: .regularExpression) {
            author = String(script[authorMatch]).replacingOccurrences(of: #"@author\s+"#, with: "", options: .regularExpression)
        }

        return MusicSourceConfig(
            name: name,
            description: description,
            version: version,
            author: author,
            platforms: MusicPlatform.allCases,
            scriptContent: script,
            subscriptionUrl: subscriptionUrl
        )
    }

    private func parseSongsFromJS(_ jsValue: JSValue) -> [Song] {
        guard let array = jsValue.toArray() else { return [] }
        return array.compactMap { item -> Song? in
            guard let dict = item as? [String: Any] else { return nil }
            return Song(
                id: "\(dict["platform"] ?? "")_\(dict["id"] ?? UUID().uuidString)",
                name: dict["name"] as? String ?? "",
                artist: dict["artist"] as? String ?? "",
                album: dict["album"] as? String ?? "",
                duration: dict["duration"] as? TimeInterval ?? 0,
                platform: MusicPlatform(rawValue: dict["platform"] as? String ?? "") ?? .netease,
                platformId: dict["id"] as? String ?? "",
                coverUrl: dict["coverUrl"] as? String
            )
        }
    }
}

// MARK: - 错误

enum MusicSourceError: LocalizedError {
    case invalidURL
    case invalidScript
    case noSubscriptionURL
    case engineNotReady
    case noPlayUrl
    case scriptError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "无效的订阅地址"
        case .invalidScript: return "脚本格式无效"
        case .noSubscriptionURL: return "没有订阅地址"
        case .engineNotReady: return "音源引擎未就绪，请先添加音源"
        case .noPlayUrl: return "无法获取播放链接"
        case .scriptError(let msg): return "脚本错误: \(msg)"
        }
    }
}
