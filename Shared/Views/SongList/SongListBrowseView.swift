import SwiftUI

// MARK: - 歌单浏览页（在线热门歌单）

struct SongListBrowseView: View {
    @Environment(MusicSourceEngine.self) private var engine
    @Environment(PlayerViewModel.self) private var playerVM

    @State private var selectedPlatform: MusicPlatform = .netease
    @State private var playlists: [OnlinePlaylist] = []
    @State private var isLoading = false
    @State private var selectedPlaylist: OnlinePlaylist?
    @State private var playlistSongs: [Song] = []
    @State private var isLoadingSongs = false

    var body: some View {
        VStack(spacing: 0) {
            // 平台选择
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach([MusicPlatform.netease, .qq], id: \.self) { p in
                        Button {
                            selectedPlatform = p
                            Task { await loadPlaylists() }
                        } label: {
                            Text(p.displayName)
                                .font(.subheadline.weight(selectedPlatform == p ? .bold : .regular))
                                .foregroundStyle(selectedPlatform == p ? .white : .primary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(selectedPlatform == p ? Color.purple : Color(.secondarySystemFill))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 10)

            // 歌单列表或歌单详情
            if let playlist = selectedPlaylist {
                playlistDetailView(playlist)
            } else {
                playlistGridView
            }
        }
        .navigationTitle("歌单")
        .task { await loadPlaylists() }
    }

    // MARK: - 歌单网格

    private var playlistGridView: some View {
        Group {
            if isLoading {
                VStack {
                    Spacer()
                    ProgressView("加载中...")
                    Spacer()
                }
            } else if playlists.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "music.note.list")
                        .font(.system(size: 48))
                        .foregroundStyle(.quaternary)
                    Text("暂无歌单")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 16)
                    ], spacing: 16) {
                        ForEach(playlists) { playlist in
                            Button {
                                selectedPlaylist = playlist
                                Task { await loadPlaylistSongs(playlist) }
                            } label: {
                                playlistCard(playlist)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                }
            }
        }
    }

    private func playlistCard(_ playlist: OnlinePlaylist) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // 封面
            AsyncImage(url: URL(string: playlist.coverUrl)) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(LinearGradient(colors: [.purple.opacity(0.5), .blue.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .overlay {
                            Image(systemName: "music.note.list")
                                .font(.title)
                                .foregroundStyle(.white.opacity(0.5))
                        }
                }
            }
            .frame(height: 150)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            // 信息
            Text(playlist.name)
                .font(.caption.bold())
                .lineLimit(2)
            if let count = playlist.playCount {
                Text("\(formatPlayCount(count)) 次播放")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - 歌单详情

    private func playlistDetailView(_ playlist: OnlinePlaylist) -> some View {
        VStack(spacing: 0) {
            // 返回按钮
            HStack {
                Button {
                    selectedPlaylist = nil
                    playlistSongs = []
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("返回")
                    }
                    .font(.subheadline)
                }
                .buttonStyle(.plain)

                Spacer()

                Text(playlist.name)
                    .font(.subheadline.bold())
                    .lineLimit(1)

                Spacer()

                if !playlistSongs.isEmpty {
                    Button {
                        Task {
                            playerVM.audioPlayer.setQueue(playlistSongs, startIndex: 0)
                            if let first = playlistSongs.first {
                                await playerVM.playSong(first, engine: engine)
                            }
                        }
                    } label: {
                        Label("播放全部", systemImage: "play.fill")
                            .font(.caption.bold())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.purple)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            if isLoadingSongs {
                VStack {
                    Spacer()
                    ProgressView("加载歌曲...")
                    Spacer()
                }
            } else {
                List {
                    ForEach(Array(playlistSongs.enumerated()), id: \.element.id) { index, song in
                        HStack(spacing: 12) {
                            Text("\(index + 1)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 24)
                            AlbumCover(platform: song.platform, size: 40, coverUrl: song.coverUrl)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(song.name)
                                    .font(.subheadline)
                                    .lineLimit(1)
                                Text(song.artist)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            Task {
                                await playerVM.playSongFromSearchResult(song, allResults: playlistSongs, engine: engine)
                            }
                        }
                        .songContextMenu(song)
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    // MARK: - 数据加载

    private func loadPlaylists() async {
        isLoading = true
        do {
            playlists = try await engine.getOnlinePlaylists(platform: selectedPlatform)
        } catch {
            print("[SongListBrowse] 加载失败: \(error)")
            playlists = []
        }
        isLoading = false
    }

    private func loadPlaylistSongs(_ playlist: OnlinePlaylist) async {
        isLoadingSongs = true
        do {
            let result = try await engine.importPlaylist(url: playlist.detailUrl)
            playlistSongs = result.songs
        } catch {
            print("[SongListBrowse] 加载歌曲失败: \(error)")
            playlistSongs = []
        }
        isLoadingSongs = false
    }

    private func formatPlayCount(_ count: Int) -> String {
        if count >= 100_000_000 { return "\(count / 100_000_000)亿" }
        if count >= 10_000 { return "\(count / 10_000)万" }
        return "\(count)"
    }
}

// MARK: - 在线歌单模型

struct OnlinePlaylist: Identifiable {
    let id: String
    let name: String
    let coverUrl: String
    let detailUrl: String
    let playCount: Int?
}
