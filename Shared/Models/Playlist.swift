import Foundation
import SwiftData

/// 歌单模型
@Model
final class Playlist {
    @Attribute(.unique) var id: String
    var name: String
    var desc: String
    var coverUrl: String?
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade) var items: [PlaylistItem] = []

    init(name: String, desc: String = "") {
        self.id = UUID().uuidString
        self.name = name
        self.desc = desc
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var songCount: Int { items.count }
}

/// 歌单中的歌曲条目
@Model
final class PlaylistItem {
    var songId: String
    var songName: String
    var artist: String
    var album: String
    var duration: TimeInterval
    var platformRaw: String
    var platformId: String
    var coverUrl: String?
    var order: Int

    @Relationship(inverse: \Playlist.items) var playlist: Playlist?

    var platform: MusicPlatform {
        MusicPlatform(rawValue: platformRaw) ?? .netease
    }

    init(song: Song, order: Int) {
        self.songId = song.id
        self.songName = song.name
        self.artist = song.artist
        self.album = song.album
        self.duration = song.duration
        self.platformRaw = song.platform.rawValue
        self.platformId = song.platformId
        self.coverUrl = song.coverUrl
        self.order = order
    }

    func toSong() -> Song {
        Song(
            id: songId,
            name: songName,
            artist: artist,
            album: album,
            duration: duration,
            platform: platform,
            platformId: platformId,
            coverUrl: coverUrl
        )
    }
}
