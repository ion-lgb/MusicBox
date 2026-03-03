import SwiftUI

// MARK: - 歌单列表

struct PlaylistListView: View {
    @Environment(PlaylistViewModel.self) private var playlistVM
    @State private var showCreate = false
    @State private var newName = ""

    var body: some View {
        Group {
            if playlistVM.playlists.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "music.note.list")
                        .font(.system(size: 50, weight: .light))
                        .foregroundStyle(.quaternary)
                    Text("暂无歌单")
                        .font(.title3.bold())
                    Text("点击 + 创建")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(playlistVM.playlists) { pl in
                        NavigationLink { PlaylistDetailView(playlist: pl) } label: {
                            HStack(spacing: 14) {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(LinearGradient(
                                        colors: [.purple, .purple.opacity(0.5)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing
                                    ))
                                    .frame(width: 50, height: 50)
                                    .overlay {
                                        Image(systemName: "music.note.list")
                                            .foregroundStyle(.white.opacity(0.9))
                                    }

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(pl.name)
                                        .font(.body.weight(.medium))
                                    Text("\(pl.songCount) 首")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .onDelete { idx in
                        for i in idx { playlistVM.deletePlaylist(playlistVM.playlists[i]) }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("歌单")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackgroundVisibility(.visible, for: .navigationBar)
        .toolbarBackgroundVisibility(.visible, for: .tabBar)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showCreate = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .alert("新建歌单", isPresented: $showCreate) {
            TextField("名称", text: $newName)
            Button("取消", role: .cancel) { newName = "" }
            Button("创建") {
                guard !newName.isEmpty else { return }
                playlistVM.createPlaylist(name: newName)
                newName = ""
            }
        }
    }
}

// MARK: - 歌单详情

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
                        .font(.system(size: 44, weight: .light))
                        .foregroundStyle(.quaternary)
                    Text("空歌单")
                        .font(.title3.bold())
                    Text("搜索歌曲并添加到这里")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        let sorted = playlist.items.sorted { $0.order < $1.order }
                        ForEach(Array(sorted.enumerated()), id: \.element.id) { idx, item in
                            let song = item.toSong()
                            SongRow(song: song, index: idx + 1) {
                                let songs = sorted.map { $0.toSong() }
                                Task { await playerVM.playSongFromSearchResult(song, allResults: songs, engine: engine) }
                            }
                            if idx < sorted.count - 1 {
                                Divider().padding(.leading, 76)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
        .navigationTitle(playlist.name)
    }
}
