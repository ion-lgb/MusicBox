import Foundation

/// 歌曲模型 - 统一格式
struct Song: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let artist: String
    let album: String
    let duration: TimeInterval  // 秒
    let platform: MusicPlatform
    let platformId: String      // 平台原始 ID
    let coverUrl: String?
    var playUrl: String?        // 播放链接（懒加载）

    var durationText: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

/// 音乐平台枚举
enum MusicPlatform: String, Codable, CaseIterable, Identifiable {
    case netease = "netease"
    case qq = "qq"
    case kugou = "kugou"
    case migu = "migu"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .netease: return "网易云"
        case .qq: return "QQ音乐"
        case .kugou: return "酷狗"
        case .migu: return "咪咕"
        }
    }

    var iconColor: String {
        switch self {
        case .netease: return "#E60026"
        case .qq: return "#31C27C"
        case .kugou: return "#2CA2F9"
        case .migu: return "#FF6633"
        }
    }
}

/// 搜索结果
struct SearchResult: Identifiable {
    let id = UUID()
    let platform: MusicPlatform
    let songs: [Song]
    let total: Int
}

/// 音质选择
enum MusicQuality: String, CaseIterable, Identifiable, Codable {
    case standard = "128k"
    case high = "320k"
    case lossless = "flac"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .standard: return "标准 128K"
        case .high: return "高品质 320K"
        case .lossless: return "无损 FLAC"
        }
    }

    var icon: String {
        switch self {
        case .standard: return "speaker.wave.1"
        case .high: return "speaker.wave.2"
        case .lossless: return "speaker.wave.3"
        }
    }
}
