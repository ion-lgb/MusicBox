import SwiftUI

/// 歌单列表页
struct PlaylistListView: View {
    @Environment(PlaylistViewModel.self) private var playlistVM
    @State private var showCreateSheet = false
    @State private var newPlaylistName = ""

    var body: some View {
        List {
            if playlistVM.playlists.isEmpty {
                ContentUnavailableView(
                    "还没有歌单",
                    systemImage: "music.note.list",
                    description: Text("点击右上角 + 创建歌单")
                )
            } else {
                ForEach(playlistVM.playlists) { playlist in
                    NavigationLink {
                        PlaylistDetailView(playlist: playlist)
                    } label: {
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(
                                    LinearGradient(
                                        colors: [.accentColor, .accentColor.opacity(0.5)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 48, height: 48)
                                .overlay {
                                    Image(systemName: "music.note.list")
                                        .foregroundStyle(.white)
                                }

                            VStack(alignment: .leading, spacing: 3) {
                                Text(playlist.name)
                                    .font(.body.weight(.medium))
                                Text("\(playlist.songCount) 首歌曲")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        playlistVM.deletePlaylist(playlistVM.playlists[index])
                    }
                }
            }
        }
        .navigationTitle("我的歌单")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .alert("新建歌单", isPresented: $showCreateSheet) {
            TextField("歌单名称", text: $newPlaylistName)
            Button("取消", role: .cancel) {
                newPlaylistName = ""
            }
            Button("创建") {
                if !newPlaylistName.isEmpty {
                    playlistVM.createPlaylist(name: newPlaylistName)
                    newPlaylistName = ""
                }
            }
        }
    }
}

/// 歌单详情页
struct PlaylistDetailView: View {
    let playlist: Playlist
    @Environment(PlayerViewModel.self) private var playerVM
    @Environment(MusicSourceEngine.self) private var engine

    var body: some View {
        List {
            if playlist.items.isEmpty {
                ContentUnavailableView(
                    "歌单是空的",
                    systemImage: "music.note",
                    description: Text("搜索歌曲并添加到歌单")
                )
            } else {
                ForEach(playlist.items.sorted(by: { $0.order < $1.order })) { item in
                    let song = item.toSong()
                    SongRow(song: song) {
                        let songs = playlist.items.sorted(by: { $0.order < $1.order }).map { $0.toSong() }
                        Task {
                            await playerVM.playSongFromSearchResult(song, allResults: songs, engine: engine)
                        }
                    }
                }
            }
        }
        .navigationTitle(playlist.name)
        .listStyle(.plain)
    }
}
