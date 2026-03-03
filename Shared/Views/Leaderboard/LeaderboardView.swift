import SwiftUI

// MARK: - 排行榜页面

struct LeaderboardView: View {
    @Environment(MusicSourceEngine.self) private var engine
    @Environment(PlayerViewModel.self) private var playerVM

    @State private var selectedPlatform: MusicPlatform = .netease
    @State private var selectedBoard: LeaderboardType = .hot
    @State private var songs: [Song] = []
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 0) {
            // 顶部选择
            VStack(spacing: 12) {
                // 平台选择
                HStack(spacing: 12) {
                    ForEach(MusicPlatform.allCases) { platform in
                        Button {
                            selectedPlatform = platform
                            loadBoard()
                        } label: {
                            Text(platform.displayName)
                                .font(.subheadline.weight(selectedPlatform == platform ? .bold : .regular))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(selectedPlatform == platform ? DS.color(for: platform) : Color.clear)
                                .foregroundStyle(selectedPlatform == platform ? .white : .primary)
                                .clipShape(Capsule())
                                .overlay {
                                    if selectedPlatform != platform {
                                        Capsule().stroke(.quaternary)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }

                // 榜单类型选择
                HStack(spacing: 10) {
                    ForEach(LeaderboardType.allCases) { board in
                        Button {
                            selectedBoard = board
                            loadBoard()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: board.icon)
                                Text(board.displayName)
                            }
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(selectedBoard == board ? DS.color(for: selectedPlatform).opacity(0.15) : Color.clear)
                            .foregroundStyle(selectedBoard == board ? DS.color(for: selectedPlatform) : .secondary)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            Divider()

            // 歌曲列表
            if isLoading {
                VStack(spacing: 12) {
                    Spacer()
                    ProgressView()
                    Text("加载中...")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else if songs.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 48))
                        .foregroundStyle(.quaternary)
                    Text("暂无数据")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
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
                                    .background(DS.color(for: selectedPlatform))
                                    .foregroundStyle(.white)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)

                            Text("\(songs.count) 首歌曲")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)

                        ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
                            LeaderboardRow(song: song, rank: index + 1, platform: selectedPlatform) {
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
        .navigationTitle("排行榜")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackgroundVisibility(.visible, for: .navigationBar)
        .toolbarBackgroundVisibility(.visible, for: .tabBar)
        #endif
        .onAppear { loadBoard() }
    }

    private func loadBoard() {
        isLoading = true
        songs = []
        Task {
            songs = await engine.getLeaderboard(platform: selectedPlatform, type: selectedBoard)
            isLoading = false
        }
    }
}

// MARK: - 排行榜歌曲行

struct LeaderboardRow: View {
    let song: Song
    let rank: Int
    let platform: MusicPlatform
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // 排名
                Text("\(rank)")
                    .font(.system(size: 16, weight: rank <= 3 ? .bold : .regular, design: .rounded))
                    .foregroundStyle(rank <= 3 ? DS.color(for: platform) : .secondary)
                    .frame(width: 30)

                // 封面
                AlbumCover(platform: song.platform, size: 44, coverUrl: song.coverUrl)

                // 信息
                VStack(alignment: .leading, spacing: 3) {
                    Text(song.name)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                    Text(song.artist)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Text(song.durationText)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 排行榜类型

enum LeaderboardType: String, CaseIterable, Identifiable {
    case hot = "hot"
    case new = "new"
    case soar = "soar"
    case original = "original"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .hot: return "热歌榜"
        case .new: return "新歌榜"
        case .soar: return "飙升榜"
        case .original: return "原创榜"
        }
    }

    var icon: String {
        switch self {
        case .hot: return "flame.fill"
        case .new: return "sparkles"
        case .soar: return "chart.line.uptrend.xyaxis"
        case .original: return "star.fill"
        }
    }
}
