import SwiftUI

// MARK: - 歌单导入页面

struct SongListView: View {
    @Environment(MusicSourceEngine.self) private var engine
    @Environment(PlayerViewModel.self) private var playerVM

    @State private var inputUrl = ""
    @State private var songs: [Song] = []
    @State private var playlistName = ""
    @State private var isLoading = false
    @State private var errorMsg: String?

    var body: some View {
        VStack(spacing: 0) {
            // 输入区
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "link")
                        .foregroundStyle(.secondary)
                    TextField("粘贴歌单链接（网易云/QQ音乐）", text: $inputUrl)
                        .textFieldStyle(.plain)
                        .onSubmit { importPlaylist() }

                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Button("导入") { importPlaylist() }
                            .disabled(inputUrl.isEmpty)
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                    }
                }
                .padding(10)
                .background(.quaternary.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                if let error = errorMsg {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(error)
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            Divider()

            // 歌曲列表
            if songs.isEmpty && !isLoading {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "rectangle.stack.badge.plus")
                        .font(.system(size: 48))
                        .foregroundStyle(.quaternary)
                    Text("粘贴歌单链接即可导入")
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("支持的链接格式：")
                            .font(.caption.bold())
                        Text("• 网易云: https://music.163.com/playlist?id=xxx")
                        Text("• QQ音乐: https://y.qq.com/n/ryqq/playlist/xxx")
                    }
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(16)
                    .background(.quaternary.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else if !songs.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        // 操作栏
                        HStack(spacing: 12) {
                            Button {
                                Task {
                                    playerVM.audioPlayer.setQueue(songs, startIndex: 0)
                                    if let first = songs.first {
                                        await playerVM.playSong(first, engine: engine)
                                    }
                                }
                            } label: {
                                Label("播放全部", systemImage: "play.fill")
                                    .font(.subheadline.bold())
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 7)
                                    .background(.purple)
                                    .foregroundStyle(.white)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)

                            if !playlistName.isEmpty {
                                Text(playlistName)
                                    .font(.subheadline.bold())
                            }

                            Text("\(songs.count) 首歌曲")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)

                        ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
                            LeaderboardRow(song: song, rank: index + 1, platform: song.platform) {
                                Task {
                                    await playerVM.playSongFromSearchResult(song, allResults: songs, engine: engine)
                                }
                            }
                            .songContextMenu(song)
                        }
                    }
                }
            }
        }
        .navigationTitle("歌单导入")
    }

    private func importPlaylist() {
        guard !inputUrl.isEmpty else { return }
        isLoading = true
        errorMsg = nil
        songs = []

        Task {
            do {
                let result = try await engine.importPlaylist(url: inputUrl)
                playlistName = result.name
                songs = result.songs
            } catch {
                errorMsg = error.localizedDescription
            }
            isLoading = false
        }
    }
}
