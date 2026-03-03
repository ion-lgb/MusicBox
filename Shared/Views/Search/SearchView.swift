import SwiftUI

/// 搜索视图
struct SearchView: View {
    @Environment(SearchViewModel.self) private var searchVM
    @Environment(PlayerViewModel.self) private var playerVM
    @Environment(MusicSourceEngine.self) private var engine

    var body: some View {
        @Bindable var vm = searchVM
        VStack(spacing: 0) {
            // 搜索栏
            searchBar

            // 平台筛选
            platformFilter

            // 搜索结果
            if searchVM.isSearching {
                Spacer()
                ProgressView("搜索中...")
                    .padding()
                Spacer()
            } else if let error = searchVM.errorMessage {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text(error)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            } else if searchVM.results.isEmpty && !searchVM.keyword.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "music.note")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("没有找到相关歌曲")
                        .foregroundStyle(.secondary)
                }
                Spacer()
            } else if searchVM.results.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "music.quarternote.3")
                        .font(.system(size: 48))
                        .foregroundStyle(.tertiary)
                    Text(engine.isLoaded ? "输入关键词搜索音乐" : "请先在设置中添加音源")
                        .foregroundStyle(.secondary)
                }
                Spacer()
            } else {
                songList
            }
        }
        .navigationTitle("搜索")
    }

    // MARK: - 子视图

    private var searchBar: some View {
        @Bindable var vm = searchVM
        return HStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("搜索歌曲、歌手...", text: $vm.keyword)
                    .textFieldStyle(.plain)
                    .onSubmit {
                        Task { await searchVM.search(engine: engine) }
                    }
                if !searchVM.keyword.isEmpty {
                    Button {
                        searchVM.clear()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            Button("搜索") {
                Task { await searchVM.search(engine: engine) }
            }
            .buttonStyle(.borderedProminent)
            .disabled(searchVM.keyword.isEmpty || searchVM.isSearching)
        }
        .padding()
    }

    private var platformFilter: some View {
        @Bindable var vm = searchVM
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(title: "全部", isSelected: searchVM.selectedPlatform == nil) {
                    searchVM.selectedPlatform = nil
                    if !searchVM.keyword.isEmpty {
                        Task { await searchVM.search(engine: engine) }
                    }
                }
                ForEach(MusicPlatform.allCases) { platform in
                    FilterChip(
                        title: platform.displayName,
                        isSelected: searchVM.selectedPlatform == platform
                    ) {
                        searchVM.selectedPlatform = platform
                        if !searchVM.keyword.isEmpty {
                            Task { await searchVM.search(engine: engine) }
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.bottom, 8)
    }

    private var songList: some View {
        List(searchVM.results) { song in
            SongRow(song: song) {
                Task {
                    await playerVM.playSongFromSearchResult(
                        song, allResults: searchVM.results, engine: engine
                    )
                }
            }
        }
        .listStyle(.plain)
    }
}

/// 平台筛选标签
struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.callout)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.12))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// 歌曲行
struct SongRow: View {
    let song: Song
    let onTap: () -> Void

    @Environment(PlayerViewModel.self) private var playerVM

    private var isCurrentSong: Bool {
        playerVM.audioPlayer.currentSong?.id == song.id
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // 平台标识
                platformBadge

                // 歌曲信息
                VStack(alignment: .leading, spacing: 3) {
                    Text(song.name)
                        .font(.body)
                        .fontWeight(isCurrentSong ? .semibold : .regular)
                        .foregroundStyle(isCurrentSong ? Color.accentColor : .primary)
                        .lineLimit(1)
                    Text("\(song.artist) · \(song.album)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                // 时长
                Text(song.durationText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()

                // 正在播放指示
                if isCurrentSong {
                    Image(systemName: playerVM.audioPlayer.isPlaying ? "speaker.wave.2.fill" : "speaker.fill")
                        .font(.caption)
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var platformBadge: some View {
        Text(String(song.platform.displayName.prefix(1)))
            .font(.caption2.bold())
            .frame(width: 24, height: 24)
            .background(Color(hex: song.platform.iconColor) ?? .gray)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
