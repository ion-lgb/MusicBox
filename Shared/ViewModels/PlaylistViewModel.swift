import Foundation
import SwiftData

/// 歌单 ViewModel
@MainActor @Observable
final class PlaylistViewModel {
    var playlists: [Playlist] = []
    var errorMessage: String?

    private var modelContext: ModelContext?

    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        fetchPlaylists()
    }

    func fetchPlaylists() {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<Playlist>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        playlists = (try? context.fetch(descriptor)) ?? []
    }

    func createPlaylist(name: String, desc: String = "") {
        guard let context = modelContext else { return }
        let playlist = Playlist(name: name, desc: desc)
        context.insert(playlist)
        try? context.save()
        fetchPlaylists()
    }

    func deletePlaylist(_ playlist: Playlist) {
        guard let context = modelContext else { return }
        context.delete(playlist)
        try? context.save()
        fetchPlaylists()
    }

    func addSongToPlaylist(_ song: Song, playlist: Playlist) {
        guard let context = modelContext else { return }
        let item = PlaylistItem(song: song, order: playlist.items.count)
        playlist.items.append(item)
        playlist.updatedAt = Date()
        try? context.save()
    }

    func removeSongFromPlaylist(_ item: PlaylistItem, playlist: Playlist) {
        guard let context = modelContext else { return }
        playlist.items.removeAll { $0.songId == item.songId }
        playlist.updatedAt = Date()
        try? context.save()
    }

    func renamePlaylist(_ playlist: Playlist, name: String) {
        guard let context = modelContext else { return }
        playlist.name = name
        playlist.updatedAt = Date()
        try? context.save()
        fetchPlaylists()
    }
}
