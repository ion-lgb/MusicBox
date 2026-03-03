import SwiftUI

/// 歌单列表页
struct PlaylistListView: View {
    @Environment(PlaylistViewModel.self) private var playlistVM
    @State private var showCreateSheet = false
    @State private var newPlaylistName = ""

    var body: some View {
        Group {
            if playlistVM.playlists.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "music.note.list")
                        .font(.system(size: 48))
                        .foregroundStyle(.tertiary)
                        .symbolRenderingMode(.hierarchical)
                    Text("还没有歌单")
                        .font(.title3.weight(.semibold))
                    Text("点击右上角 + 创建歌单")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(playlistVM.playlists) { playlist in
                            NavigationLink {
                                PlaylistDetailView(playlist: playlist)
                            } label: {
                                PlaylistCard(playlist: playlist)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, DesignTokens.spacingMD)
                    .padding(.vertical, DesignTokens.spacingSM)
                }
            }
        }
        .navigationTitle("我的歌单")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showCreateSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .font(.title3)
                }
            }
        }
        .alert("新建歌单", isPresented: $showCreateSheet) {
            TextField("歌单名称", text: $newPlaylistName)
            Button("取消", role: .cancel) { newPlaylistName = "" }
            Button("创建") {
                if !newPlaylistName.isEmpty {
                    playlistVM.createPlaylist(name: newPlaylistName)
                    newPlaylistName = ""
                }
            }
        }
    }
}

/// 歌单卡片
struct PlaylistCard: View {
    let playlist: Playlist

    var body: some View {
        HStack(spacing: 14) {
            // 歌单封面
            RoundedRectangle(cornerRadius: DesignTokens.radiusMD)
                .fill(DesignTokens.accentGradient)
                .frame(width: 56, height: 56)
                .overlay {
                    Image(systemName: "music.note.list")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.9))
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(playlist.name)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                Text("\(playlist.songCount) 首歌曲")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(Color(.secondarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusMD))
    }
}

/// 歌单详情页
struct PlaylistDetailView: View {
    let playlist: Playlist
    @Environment(PlayerViewModel.self) private var playerVM
    @Environment(MusicSourceEngine.self) private var engine

    var body: some View {
        Group {
            if playlist.items.isEmpty {
                VStack(spacing: 14) {
                    Spacer()
                    Image(systemName: "music.note")
                        .font(.system(size: 42))
                        .foregroundStyle(.tertiary)
                        .symbolRenderingMode(.hierarchical)
                    Text("歌单是空的")
                        .font(.title3.weight(.semibold))
                    Text("搜索歌曲并添加到歌单")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(Array(playlist.items.sorted(by: { $0.order < $1.order }).enumerated()), id: \.element.id) { index, item in
                            let song = item.toSong()
                            SongRow(song: song, index: index + 1) {
                                let songs = playlist.items.sorted(by: { $0.order < $1.order }).map { $0.toSong() }
                                Task {
                                    await playerVM.playSongFromSearchResult(song, allResults: songs, engine: engine)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, DesignTokens.spacingMD)
                    .padding(.vertical, DesignTokens.spacingSM)
                }
            }
        }
        .navigationTitle(playlist.name)
    }
}
