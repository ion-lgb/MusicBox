import Foundation
@preconcurrency import JavaScriptCore
import CryptoKit

/// 音源引擎 - 兼容洛雪自定义源脚本 + 内置搜索
@MainActor @Observable
final class MusicSourceEngine {
    private var jsContext: JSContext?
    private(set) var sources: [MusicSourceConfig] = []
    private(set) var isLoaded = false
    private(set) var errorMessage: String?

    /// 洛雪脚本注册的 request handler
    private var requestHandler: JSValue?
    /// 洛雪脚本 inited 时声明的源信息
    private var scriptSources: [String: Any] = [:]

    private let storage = MusicSourceStorage()

    init() {
        loadSavedSources()
    }

    // MARK: - 音源管理

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

    func removeSource(_ source: MusicSourceConfig) throws {
        try storage.deleteSource(id: source.id)
        sources.removeAll { $0.id == source.id }
        if sources.isEmpty {
            jsContext = nil
            requestHandler = nil
            isLoaded = false
        } else {
            try setupJSContext()
        }
    }

    // MARK: - 内置搜索（直接调用各平台 API）

    func search(keyword: String, platform: MusicPlatform? = nil) async throws -> [Song] {
        guard isLoaded else {
            throw MusicSourceError.engineNotReady
        }

        let platforms: [MusicPlatform] = platform.map { [$0] } ?? MusicPlatform.allCases

        var allSongs: [Song] = []

        await withTaskGroup(of: [Song].self) { group in
            for p in platforms {
                group.addTask {
                    do {
                        return try await self.searchPlatform(keyword: keyword, platform: p)
                    } catch {
                        print("[Search] \(p.displayName) 搜索失败: \(error)")
                        return []
                    }
                }
            }
            for await songs in group {
                allSongs.append(contentsOf: songs)
            }
        }
        return allSongs
    }

    /// 通过洛雪脚本获取歌曲播放 URL
    func getSongUrl(song: Song) async throws -> String {
        guard isLoaded else {
            throw MusicSourceError.engineNotReady
        }

        guard let handler = requestHandler else {
            print("[LX] requestHandler 为空，脚本可能未注册 on('request') 事件")
            print("[LX] scriptSources: \(scriptSources.keys.sorted())")
            throw MusicSourceError.scriptError("音源脚本未注册 request handler，请检查脚本是否正确")
        }

        let sourceKey = song.platform.lxSourceKey
        print("[LX] 请求播放链接: source=\(sourceKey), songId=\(song.platformId), name=\(song.name)")

        // 检查脚本是否支持该平台
        if !scriptSources.isEmpty && scriptSources[sourceKey] == nil {
            let supported = scriptSources.keys.sorted().joined(separator: ", ")
            print("[LX] 脚本不支持 \(sourceKey)，支持的源: \(supported)")
            throw MusicSourceError.scriptError("音源脚本不支持 \(song.platform.displayName)（支持: \(supported)）")
        }

        return try await withCheckedThrowingContinuation { continuation in
            let musicInfo: [String: Any] = [
                "songmid": song.platformId,
                "name": song.name,
                "singer": song.artist,
                "album": song.album,
                "source": sourceKey,
                "id": song.platformId,
                "hash": song.platformId
            ]

            let info: [String: Any] = [
                "type": "128k",
                "musicInfo": musicInfo
            ]

            let params: [String: Any] = [
                "source": sourceKey,
                "action": "musicUrl",
                "info": info
            ]

            guard let context = jsContext else {
                continuation.resume(throwing: MusicSourceError.engineNotReady)
                return
            }

            let paramsJSValue = JSValue(object: params, in: context)!

            guard let promise = handler.call(withArguments: [paramsJSValue]) else {
                print("[LX] handler.call 返回 nil")
                continuation.resume(throwing: MusicSourceError.noPlayUrl)
                return
            }

            let thenBlock: @convention(block) (JSValue?) -> Void = { result in
                guard let url = result?.toString(), !url.isEmpty, url != "undefined", url != "null" else {
                    print("[LX] handler 返回了空 URL")
                    continuation.resume(throwing: MusicSourceError.noPlayUrl)
                    return
                }
                print("[LX] 获取到播放 URL: \(url.prefix(80))...")
                continuation.resume(returning: url)
            }

            let catchBlock: @convention(block) (JSValue?) -> Void = { error in
                let msg = error?.toString() ?? "Unknown error"
                print("[LX] handler Promise 被 reject: \(msg)")
                continuation.resume(throwing: MusicSourceError.scriptError(msg))
            }

            promise.invokeMethod("then", withArguments: [
                JSValue(object: thenBlock, in: context)!
            ]).invokeMethod("catch", withArguments: [
                JSValue(object: catchBlock, in: context)!
            ])
        }
    }

    /// 内置歌词获取（各平台独立 API）
    func getLyric(song: Song) async -> String {
        do {
            switch song.platform {
            case .netease:
                return try await getLyricNetease(id: song.platformId)
            case .qq:
                return try await getLyricQQ(mid: song.platformId)
            case .kugou:
                return try await getLyricKugou(hash: song.platformId)
            case .migu:
                return try await getLyricMigu(id: song.platformId)
            }
        } catch {
            print("[Lyric] 获取歌词失败: \(error)")
            return ""
        }
    }

    // MARK: - 各平台歌词 API

    private func getLyricNetease(id: String) async throws -> String {
        let url = URL(string: "https://music.163.com/api/song/lyric?id=\(id)&lv=1&tv=1")!
        var req = URLRequest(url: url)
        req.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        req.setValue("https://music.163.com", forHTTPHeaderField: "Referer")
        let (data, _) = try await URLSession.shared.data(for: req)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let lrc = json["lrc"] as? [String: Any],
              let lyric = lrc["lyric"] as? String else { return "" }
        return lyric
    }

    private func getLyricQQ(mid: String) async throws -> String {
        let url = URL(string: "https://c.y.qq.com/lyric/fcgi-bin/fcg_query_lyric_new.fcg?songmid=\(mid)&format=json&nobase64=1")!
        var req = URLRequest(url: url)
        req.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        req.setValue("https://y.qq.com", forHTTPHeaderField: "Referer")
        let (data, _) = try await URLSession.shared.data(for: req)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let lyric = json["lyric"] as? String else { return "" }
        return lyric
    }

    private func getLyricKugou(hash: String) async throws -> String {
        // 先获取 accesskey
        let searchUrl = URL(string: "https://krcs.kugou.com/search?ver=1&man=yes&hash=\(hash)")!
        var req1 = URLRequest(url: searchUrl)
        req1.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        let (data1, _) = try await URLSession.shared.data(for: req1)
        guard let json1 = try JSONSerialization.jsonObject(with: data1) as? [String: Any],
              let candidates = json1["candidates"] as? [[String: Any]],
              let first = candidates.first,
              let accesskey = first["accesskey"] as? String,
              let kid = first["id"] as? String else { return "" }

        // 再获取歌词
        let lyricUrl = URL(string: "https://lyrics.kugou.com/download?ver=1&client=pc&id=\(kid)&accesskey=\(accesskey)&fmt=lrc")!
        var req2 = URLRequest(url: lyricUrl)
        req2.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        let (data2, _) = try await URLSession.shared.data(for: req2)
        guard let json2 = try JSONSerialization.jsonObject(with: data2) as? [String: Any],
              let content = json2["content"] as? String,
              let decoded = Data(base64Encoded: content),
              let lyric = String(data: decoded, encoding: .utf8) else { return "" }
        return lyric
    }

    private func getLyricMigu(id: String) async throws -> String {
        let url = URL(string: "https://music.migu.cn/v3/api/music/audioPlayer/getLyric?copyrightId=\(id)")!
        var req = URLRequest(url: url)
        req.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        req.setValue("https://music.migu.cn", forHTTPHeaderField: "Referer")
        let (data, _) = try await URLSession.shared.data(for: req)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let lyric = json["lyric"] as? String else { return "" }
        return lyric
    }

    // MARK: - 各平台搜索 API

    private func searchPlatform(keyword: String, platform: MusicPlatform) async throws -> [Song] {
        let encoded = keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? keyword

        switch platform {
        case .netease:
            return try await searchNetease(keyword: encoded)
        case .qq:
            return try await searchQQ(keyword: encoded)
        case .kugou:
            return try await searchKugou(keyword: encoded)
        case .migu:
            return try await searchMigu(keyword: encoded)
        }
    }

    // MARK: 网易云

    private func searchNetease(keyword: String) async throws -> [Song] {
        let url = URL(string: "https://music.163.com/api/search/get/web?s=\(keyword)&type=1&offset=0&limit=30")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        req.setValue("https://music.163.com", forHTTPHeaderField: "Referer")

        let (data, _) = try await URLSession.shared.data(for: req)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = json["result"] as? [String: Any],
              let songs = result["songs"] as? [[String: Any]] else {
            return []
        }

        return songs.compactMap { s -> Song? in
            guard let id = s["id"] as? Int,
                  let name = s["name"] as? String else { return nil }
            let artists = (s["artists"] as? [[String: Any]])?.compactMap { $0["name"] as? String }.joined(separator: " / ") ?? ""
            let albumInfo = s["album"] as? [String: Any]
            let album = albumInfo?["name"] as? String ?? ""
            let duration = (s["duration"] as? Int).map { TimeInterval($0) / 1000.0 } ?? 0
            // 封面: album.picUrl (网易云搜索 API 返回)
            var coverUrl: String? = nil
            if let picUrl = albumInfo?["picUrl"] as? String {
                coverUrl = picUrl
            } else if let albumId = albumInfo?["id"] as? Int, albumId > 0 {
                coverUrl = "https://p1.music.126.net/\(albumId)/\(albumId).jpg"
            }
            return Song(id: "wy_\(id)", name: name, artist: artists, album: album,
                       duration: duration, platform: .netease, platformId: "\(id)", coverUrl: coverUrl)
        }
    }

    // MARK: QQ 音乐

    private func searchQQ(keyword: String) async throws -> [Song] {
        let url = URL(string: "https://c.y.qq.com/soso/fcgi-bin/client_search_cp?w=\(keyword)&p=1&n=30&format=json")!
        var req = URLRequest(url: url)
        req.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        req.setValue("https://y.qq.com", forHTTPHeaderField: "Referer")

        let (data, _) = try await URLSession.shared.data(for: req)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataObj = json["data"] as? [String: Any],
              let songData = dataObj["song"] as? [String: Any],
              let list = songData["list"] as? [[String: Any]] else {
            return []
        }

        return list.compactMap { s -> Song? in
            guard let mid = s["songmid"] as? String,
                  let name = s["songname"] as? String else { return nil }
            let artists = (s["singer"] as? [[String: Any]])?.compactMap { $0["name"] as? String }.joined(separator: " / ") ?? ""
            let album = s["albumname"] as? String ?? ""
            let duration = (s["interval"] as? Int).map { TimeInterval($0) } ?? 0
            let albumMid = s["albummid"] as? String ?? ""
            let coverUrl = albumMid.isEmpty ? nil : "https://y.qq.com/music/photo_new/T002R300x300M000\(albumMid).jpg"
            return Song(id: "tx_\(mid)", name: name, artist: artists, album: album,
                       duration: duration, platform: .qq, platformId: mid, coverUrl: coverUrl)
        }
    }

    // MARK: 酷狗

    private func searchKugou(keyword: String) async throws -> [Song] {
        let url = URL(string: "https://mobileservice.kugou.com/api/v3/search/song?keyword=\(keyword)&page=1&pagesize=30")!
        var req = URLRequest(url: url)
        req.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")

        let (data, _) = try await URLSession.shared.data(for: req)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataObj = json["data"] as? [String: Any],
              let list = dataObj["info"] as? [[String: Any]] else {
            return []
        }

        return list.compactMap { s -> Song? in
            guard let hash = s["hash"] as? String else { return nil }
            let fullName = s["songname"] as? String ?? ""
            let artist = s["singername"] as? String ?? ""
            let album = s["album_name"] as? String ?? ""
            let duration = (s["duration"] as? Int).map { TimeInterval($0) } ?? 0
            // 酷狗封面
            let coverUrl = (s["trans_param"] as? [String: Any])?["union_cover"] as? String
            return Song(id: "kg_\(hash)", name: fullName, artist: artist, album: album,
                       duration: duration, platform: .kugou, platformId: hash, coverUrl: coverUrl)
        }
    }

    // MARK: 咪咕

    private func searchMigu(keyword: String) async throws -> [Song] {
        let url = URL(string: "https://m.music.migu.cn/migu/remoting/scr_search_tag?keyword=\(keyword)&pgc=1&rows=30&type=2")!
        var req = URLRequest(url: url)
        req.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        req.setValue("https://m.music.migu.cn", forHTTPHeaderField: "Referer")

        let (data, _) = try await URLSession.shared.data(for: req)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let musics = json["musics"] as? [[String: Any]] else {
            return []
        }

        return musics.compactMap { s -> Song? in
            guard let id = s["id"] as? String ?? (s["songId"] as? String),
                  let name = s["songName"] as? String else { return nil }
            let artist = s["singerName"] as? String ?? ""
            let album = s["albumName"] as? String ?? ""
            let coverUrl = s["cover"] as? String
            return Song(id: "mg_\(id)", name: name, artist: artist, album: album,
                       duration: 0, platform: .migu, platformId: id, coverUrl: coverUrl)
        }
    }

    // MARK: - 排行榜 API

    func getLeaderboard(platform: MusicPlatform, type: LeaderboardType) async -> [Song] {
        do {
            switch platform {
            case .netease:
                return try await getLeaderboardNetease(type: type)
            case .qq:
                return try await getLeaderboardQQ(type: type)
            case .kugou:
                return try await getLeaderboardKugou(type: type)
            case .migu:
                return try await searchPlatform(keyword: type == .hot ? "热歌" : "新歌", platform: .migu)
            }
        } catch {
            print("[Leaderboard] 获取排行榜失败: \(error)")
            return []
        }
    }

    private func getLeaderboardNetease(type: LeaderboardType) async throws -> [Song] {
        // 网易云榜单 ID
        let boardId: Int
        switch type {
        case .hot: boardId = 3778678  // 热歌榜
        case .new: boardId = 3779629  // 新歌榜
        case .soar: boardId = 19723756 // 飙升榜
        case .original: boardId = 2884035 // 原创榜
        }

        let url = URL(string: "https://music.163.com/api/playlist/detail?id=\(boardId)")!
        var req = URLRequest(url: url)
        req.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        req.setValue("https://music.163.com", forHTTPHeaderField: "Referer")

        let (data, _) = try await URLSession.shared.data(for: req)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = json["result"] as? [String: Any],
              let tracks = result["tracks"] as? [[String: Any]] else {
            return []
        }

        return tracks.prefix(50).compactMap { s -> Song? in
            guard let id = s["id"] as? Int,
                  let name = s["name"] as? String else { return nil }
            let artists = (s["artists"] as? [[String: Any]])?.compactMap { $0["name"] as? String }.joined(separator: " / ") ?? ""
            let albumInfo = s["album"] as? [String: Any]
            let album = albumInfo?["name"] as? String ?? ""
            let duration = (s["duration"] as? Int).map { TimeInterval($0) / 1000.0 } ?? 0
            let coverUrl = albumInfo?["picUrl"] as? String
            return Song(id: "wy_\(id)", name: name, artist: artists, album: album,
                       duration: duration, platform: .netease, platformId: "\(id)", coverUrl: coverUrl)
        }
    }

    private func getLeaderboardQQ(type: LeaderboardType) async throws -> [Song] {
        // QQ 榜单 ID
        let topId: Int
        switch type {
        case .hot: topId = 26   // 热歌榜
        case .new: topId = 27   // 新歌榜
        case .soar: topId = 4   // 飙升榜
        case .original: topId = 62 // 原创榜
        }

        let url = URL(string: "https://c.y.qq.com/v8/fcg-bin/fcg_v8_toplist_cp.fcg?topid=\(topId)&page=detail&format=json&type=top&song_begin=0&song_num=50")!
        var req = URLRequest(url: url)
        req.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        req.setValue("https://y.qq.com", forHTTPHeaderField: "Referer")

        let (data, _) = try await URLSession.shared.data(for: req)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let songlist = json["songlist"] as? [[String: Any]] else {
            return []
        }

        return songlist.compactMap { item -> Song? in
            guard let songData = item["data"] as? [String: Any],
                  let mid = songData["songmid"] as? String,
                  let name = songData["songname"] as? String else { return nil }
            let artists = (songData["singer"] as? [[String: Any]])?.compactMap { $0["name"] as? String }.joined(separator: " / ") ?? ""
            let album = songData["albumname"] as? String ?? ""
            let duration = (songData["interval"] as? Int).map { TimeInterval($0) } ?? 0
            let albumMid = songData["albummid"] as? String ?? ""
            let coverUrl = albumMid.isEmpty ? nil : "https://y.qq.com/music/photo_new/T002R300x300M000\(albumMid).jpg"
            return Song(id: "tx_\(mid)", name: name, artist: artists, album: album,
                       duration: duration, platform: .qq, platformId: mid, coverUrl: coverUrl)
        }
    }

    private func getLeaderboardKugou(type: LeaderboardType) async throws -> [Song] {
        // 酷狗排行榜 - 使用搜索热门关键词作为替代
        let keyword: String
        switch type {
        case .hot: keyword = "热歌"
        case .new: keyword = "新歌"
        case .soar: keyword = "飙升"
        case .original: keyword = "原创"
        }
        return try await searchKugou(keyword: keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? keyword)
    }

    // MARK: - JS 上下文

    private func loadSavedSources() {
        sources = storage.loadSources()
        if !sources.isEmpty {
            try? setupJSContext()
        }
    }

    private func setupJSContext() throws {
        let context = JSContext()!
        requestHandler = nil
        scriptSources = [:]

        // console
        let consoleLog: @convention(block) (JSValue) -> Void = { value in
            print("[JS]", value.toString() ?? "")
        }
        context.setObject(consoleLog, forKeyedSubscript: "log" as NSString)
        context.evaluateScript("var console = { log: log, warn: log, error: log, info: log };")

        // 注入 globalThis.lx 兼容 API
        injectLxAPI(context)

        // 注入 fetch
        injectFetch(context)

        // setTimeout / setInterval
        let setTimeoutBlock: @convention(block) (JSValue, Int) -> Void = { callback, delay in
            let cb = callback
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(delay)) {
                cb.call(withArguments: [])
            }
        }
        context.setObject(setTimeoutBlock, forKeyedSubscript: "setTimeout" as NSString)

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

    /// 注入 globalThis.lx 兼容 API
    private func injectLxAPI(_ context: JSContext) {
        // EVENT_NAMES
        let eventNames: [String: String] = [
            "inited": "inited",
            "request": "request",
            "updateAlert": "updateAlert"
        ]

        // on: 注册事件处理
        let onBlock: @convention(block) (String, JSValue) -> Void = { [weak self] eventName, handler in
            print("[LX] on('\(eventName)') 被调用")
            if eventName == "request" {
                self?.requestHandler = handler
                print("[LX] requestHandler 已注册")
            }
        }

        // send: 发送事件
        let sendBlock: @convention(block) (String, JSValue?) -> Void = { [weak self] eventName, data in
            print("[LX] send('\(eventName)') 被调用")
            if eventName == "inited" {
                if let dict = data?.toDictionary(), let srcs = dict["sources"] as? [String: Any] {
                    self?.scriptSources = srcs
                    print("[LX] 脚本初始化完成，支持源: \(srcs.keys.sorted())")
                    for (key, val) in srcs {
                        if let srcInfo = val as? [String: Any] {
                            print("[LX]   \(key): \(srcInfo["name"] ?? ""), actions=\(srcInfo["actions"] ?? []), qualitys=\(srcInfo["qualitys"] ?? [])")
                        }
                    }
                }
            }
        }

        // request: HTTP 请求
        let requestBlock: @convention(block) (String, JSValue?, JSValue?) -> JSValue? = { urlString, options, callback in
            guard let url = URL(string: urlString) else {
                callback?.call(withArguments: ["Invalid URL", NSNull(), NSNull()])
                return nil
            }

            var request = URLRequest(url: url)
            request.timeoutInterval = 15

            if let opts = options, !opts.isUndefined, !opts.isNull {
                if let method = opts.forProperty("method")?.toString(), method != "undefined" {
                    request.httpMethod = method
                }
                if let headers = opts.forProperty("headers"), !headers.isUndefined {
                    if let dict = headers.toDictionary() as? [String: String] {
                        for (k, v) in dict { request.setValue(v, forHTTPHeaderField: k) }
                    }
                }
                if let body = opts.forProperty("body"), !body.isUndefined, !body.isNull {
                    request.httpBody = body.toString()?.data(using: .utf8)
                }
            }

            URLSession.shared.dataTask(with: request) { data, response, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("[LX HTTP] 请求失败: \(urlString.prefix(60)) -> \(error.localizedDescription)")
                        callback?.call(withArguments: [error.localizedDescription, NSNull(), NSNull()])
                        return
                    }
                    let bodyString = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                    let httpResp = response as? HTTPURLResponse
                    let status = httpResp?.statusCode ?? 200
                    print("[LX HTTP] \(urlString.prefix(60)) -> \(status)")
                    print("[LX HTTP] body: \(bodyString.prefix(200))")

                    // 洛雪桌面端会自动把 JSON body 解析成对象
                    // 脚本依赖 resp.body.code 这样的对象属性访问
                    // 所以需要通过 JS 的 JSON.parse 来解析 body
                    let escapedBody = bodyString
                        .replacingOccurrences(of: "\\", with: "\\\\")
                        .replacingOccurrences(of: "\"", with: "\\\"")
                        .replacingOccurrences(of: "\n", with: "\\n")
                        .replacingOccurrences(of: "\r", with: "\\r")
                        .replacingOccurrences(of: "\t", with: "\\t")

                    // 尝试在 JS 侧解析 JSON
                    let parsedBody = context.evaluateScript("(function(){ try { return JSON.parse(\"\(escapedBody)\"); } catch(e) { return \"\(escapedBody)\"; } })()")

                    let resp = JSValue(newObjectIn: context)!
                    resp.setObject(status, forKeyedSubscript: "statusCode" as NSString)
                    resp.setObject(parsedBody, forKeyedSubscript: "body" as NSString)
                    resp.setObject(httpResp?.allHeaderFields ?? [:], forKeyedSubscript: "headers" as NSString)

                    callback?.call(withArguments: [NSNull(), resp, bodyString])
                }
            }.resume()

            return nil
        }

        // currentScriptInfo
        let scriptInfo: [String: Any] = [
            "name": sources.first?.name ?? "",
            "description": sources.first?.description ?? "",
            "version": sources.first?.version ?? "",
            "author": sources.first?.author ?? ""
        ]

        // utils 占位
        context.evaluateScript("""
        var globalThis = this;
        globalThis.lx = {
            version: 2,
            env: 'native',
            currentScriptInfo: \(jsonString(scriptInfo)),
            EVENT_NAMES: \(jsonString(eventNames)),
        };
        """)

        context.setObject(onBlock, forKeyedSubscript: "__lx_on" as NSString)
        context.setObject(sendBlock, forKeyedSubscript: "__lx_send" as NSString)
        context.setObject(requestBlock, forKeyedSubscript: "__lx_request" as NSString)

        // md5
        let md5Block: @convention(block) (String) -> String = { str in
            let d = Insecure.MD5.hash(data: Data(str.utf8))
            return d.map { String(format: "%02x", $0) }.joined()
        }
        context.setObject(md5Block, forKeyedSubscript: "__lx_md5" as NSString)

        context.evaluateScript("""
        globalThis.lx.on = __lx_on;
        globalThis.lx.send = __lx_send;
        globalThis.lx.request = __lx_request;
        globalThis.lx.utils = {
            buffer: {
                from: function(str, encoding) { return str; },
                bufToString: function(buf, format) { return String(buf); }
            },
            crypto: {
                md5: __lx_md5,
                aesEncrypt: function() { return ''; },
                randomBytes: function(size) {
                    var chars = 'abcdef0123456789';
                    var result = '';
                    for (var i = 0; i < size * 2; i++) {
                        result += chars.charAt(Math.floor(Math.random() * chars.length));
                    }
                    return result;
                },
                rsaEncrypt: function() { return ''; }
            },
            zlib: {
                inflate: function(buf) { return Promise.resolve(buf); },
                deflate: function(buf) { return Promise.resolve(buf); }
            }
        };
        """)
    }

    /// 注入 fetch
    private func injectFetch(_ context: JSContext) {
        let fetchBlock: @convention(block) (String, JSValue?) -> JSValue = { urlString, options in
            let promise = JSValue(newPromiseIn: context) { resolve, reject in
                guard let url = URL(string: urlString) else {
                    reject?.call(withArguments: ["Invalid URL: \(urlString)"])
                    return
                }
                var request = URLRequest(url: url)
                request.timeoutInterval = 15

                if let opts = options, !opts.isUndefined {
                    if let method = opts.forProperty("method")?.toString(), method != "undefined" {
                        request.httpMethod = method
                    }
                    if let headers = opts.forProperty("headers"), !headers.isUndefined {
                        if let dict = headers.toDictionary() as? [String: String] {
                            for (k, v) in dict { request.setValue(v, forHTTPHeaderField: k) }
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
                    let text = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                    let status = (response as? HTTPURLResponse)?.statusCode ?? 200

                    let responseObj = JSValue(object: [
                        "status": status, "ok": status >= 200 && status < 300
                    ], in: context)

                    let jsonFn: @convention(block) () -> JSValue? = {
                        let escaped = text
                            .replacingOccurrences(of: "\\", with: "\\\\")
                            .replacingOccurrences(of: "'", with: "\\'")
                            .replacingOccurrences(of: "\n", with: "\\n")
                            .replacingOccurrences(of: "\r", with: "\\r")
                        return JSValue(newPromiseIn: context) { res, rej in
                            let parsed = context.evaluateScript("JSON.parse('\(escaped)')")
                            res?.call(withArguments: [parsed as Any])
                        }
                    }
                    let textFn: @convention(block) () -> JSValue? = {
                        return JSValue(newPromiseIn: context) { res, _ in
                            res?.call(withArguments: [text])
                        }
                    }
                    responseObj?.setObject(jsonFn, forKeyedSubscript: "json" as NSString)
                    responseObj?.setObject(textFn, forKeyedSubscript: "text" as NSString)
                    resolve?.call(withArguments: [responseObj as Any])
                }.resume()
            }
            return promise!
        }
        context.setObject(fetchBlock, forKeyedSubscript: "fetch" as NSString)
    }

    // MARK: - 工具

    private func jsonString(_ dict: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let str = String(data: data, encoding: .utf8) else { return "{}" }
        return str
    }

    private func parseScriptConfig(_ script: String, subscriptionUrl: String? = nil) throws -> MusicSourceConfig {
        var name = "自定义音源"
        var description = ""
        var version = "1.0.0"
        var author = ""

        if let m = script.range(of: #"@name\s+(.+)"#, options: .regularExpression) {
            name = String(script[m]).replacingOccurrences(of: #"@name\s+"#, with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces)
        }
        if let m = script.range(of: #"@description\s+(.+)"#, options: .regularExpression) {
            description = String(script[m]).replacingOccurrences(of: #"@description\s+"#, with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces)
        }
        if let m = script.range(of: #"@version\s+(.+)"#, options: .regularExpression) {
            version = String(script[m]).replacingOccurrences(of: #"@version\s+"#, with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces)
        }
        if let m = script.range(of: #"@author\s+(.+)"#, options: .regularExpression) {
            author = String(script[m]).replacingOccurrences(of: #"@author\s+"#, with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces)
        }

        return MusicSourceConfig(
            name: name, description: description, version: version, author: author,
            platforms: MusicPlatform.allCases, scriptContent: script, subscriptionUrl: subscriptionUrl
        )
    }
}

// MARK: - MusicPlatform 洛雪 key 映射

extension MusicPlatform {
    /// 洛雪源 key: kw/kg/tx/wy/mg
    var lxSourceKey: String {
        switch self {
        case .netease: return "wy"
        case .qq: return "tx"
        case .kugou: return "kg"
        case .migu: return "mg"
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
