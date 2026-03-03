import Foundation

/// 音源配置模型
struct MusicSourceConfig: Identifiable, Codable {
    let id: String
    var name: String
    var description: String
    var version: String
    var author: String
    var platforms: [MusicPlatform]  // 支持的平台
    var scriptContent: String       // JS 脚本内容
    var subscriptionUrl: String?    // 订阅地址
    var lastUpdated: Date
    var isActive: Bool

    init(
        name: String,
        description: String = "",
        version: String = "1.0.0",
        author: String = "",
        platforms: [MusicPlatform] = [],
        scriptContent: String = "",
        subscriptionUrl: String? = nil
    ) {
        self.id = UUID().uuidString
        self.name = name
        self.description = description
        self.version = version
        self.author = author
        self.platforms = platforms
        self.scriptContent = scriptContent
        self.subscriptionUrl = subscriptionUrl
        self.lastUpdated = Date()
        self.isActive = true
    }
}

/// 音源存储管理
class MusicSourceStorage {
    private let fileManager = FileManager.default

    var sourcesDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("MusicBox/Sources")
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func saveSource(_ config: MusicSourceConfig) throws {
        let url = sourcesDirectory.appendingPathComponent("\(config.id).json")
        let data = try JSONEncoder().encode(config)
        try data.write(to: url)
    }

    func loadSources() -> [MusicSourceConfig] {
        guard let files = try? fileManager.contentsOfDirectory(
            at: sourcesDirectory,
            includingPropertiesForKeys: nil
        ) else { return [] }

        return files
            .filter { $0.pathExtension == "json" }
            .compactMap { url in
                guard let data = try? Data(contentsOf: url),
                      let config = try? JSONDecoder().decode(MusicSourceConfig.self, from: data)
                else { return nil }
                return config
            }
    }

    func deleteSource(id: String) throws {
        let url = sourcesDirectory.appendingPathComponent("\(id).json")
        try fileManager.removeItem(at: url)
    }
}
