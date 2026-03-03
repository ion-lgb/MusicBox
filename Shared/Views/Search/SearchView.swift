import SwiftUI

/// 搜索视图
struct SearchView: View {
    @Environment(SearchViewModel.self) private var searchVM
    @Environment(PlayerViewModel.self) private var playerVM
    @Environment(MusicSourceEngine.self) private var engine

    var body: some View {
        @Bindable var vm = searchVM
        VStack(spacing: 0) {
            // 搜索栏 + 平台筛选
            VStack(spacing: DesignTokens.spacingSM) {
                searchBar
                platformFilter
            }
            .padding(.horizontal, DesignTokens.spacingMD)
            .padding(.top, DesignTokens.spacingSM)
            .padding(.bottom, DesignTokens.spacingMD)

            Divider()

            // 内容区域
            contentArea
        }
        .navigationTitle("搜索")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
    }

    // MARK: - 搜索栏

    private var searchBar: some View {
        @Bindable var vm = searchVM
        return HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.callout)

                TextField("搜索歌曲、歌手、专辑...", text: $vm.keyword)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .onSubmit {
                        Task { await searchVM.search(engine: engine) }
                    }

                if !searchVM.keyword.isEmpty {
                    Button {
                        searchVM.clear()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                            .font(.callout)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.secondarySystemFill))
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusMD))

            Button {
                Task { await searchVM.search(engine: engine) }
            } label: {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)
            .disabled(searchVM.keyword.isEmpty || searchVM.isSearching)
        }
    }

    // MARK: - 平台筛选

    private var platformFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
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
                        color: Color(hex: platform.iconColor),
                        isSelected: searchVM.selectedPlatform == platform
                    ) {
                        searchVM.selectedPlatform = platform
                        if !searchVM.keyword.isEmpty {
                            Task { await searchVM.search(engine: engine) }
                        }
                    }
                }
            }
        }
    }

    // MARK: - 内容区域

    @ViewBuilder
    private var contentArea: some View {
        if searchVM.isSearching {
            VStack(spacing: 16) {
                Spacer()
                ProgressView()
                    .controlSize(.large)
                Text("搜索中...")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        } else if let error = searchVM.errorMessage {
            emptyState(icon: "exclamationmark.triangle.fill", title: "出错了", subtitle: error, color: .orange)
        } else if searchVM.results.isEmpty && !searchVM.keyword.isEmpty {
            emptyState(icon: "magnifyingglass", title: "没有结果", subtitle: "试试换个关键词？", color: .secondary)
        } else if searchVM.results.isEmpty {
            if engine.isLoaded {
                emptyState(icon: "music.magnifyingglass", title: "搜索音乐", subtitle: "输入关键词开始搜索", color: Color.accentColor)
            } else {
                emptyState(icon: "square.and.arrow.down", title: "添加音源", subtitle: "前往「设置」添加音源订阅地址", color: .orange)
            }
        } else {
            songList
        }
    }

    private func emptyState(icon: String, title: String, subtitle: String, color: Color) -> some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 42))
                .foregroundStyle(color.opacity(0.6))
                .symbolRenderingMode(.hierarchical)
            Text(title)
                .font(.title3.weight(.semibold))
            Text(subtitle)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, 40)
    }

    // MARK: - 歌曲列表

    private var songList: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(Array(searchVM.results.enumerated()), id: \.element.id) { index, song in
                    SongRow(song: song, index: index + 1) {
                        Task {
                            await playerVM.playSongFromSearchResult(
                                song, allResults: searchVM.results, engine: engine
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, DesignTokens.spacingMD)
            .padding(.vertical, DesignTokens.spacingSM)
        }
    }
}

// MARK: - 筛选标签

struct FilterChip: View {
    let title: String
    var color: Color? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background {
                    if isSelected {
                        Capsule().fill(color ?? Color.accentColor)
                    } else {
                        Capsule().fill(Color(.secondarySystemFill))
                    }
                }
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - 歌曲行

struct SongRow: View {
    let song: Song
    var index: Int = 0
    let onTap: () -> Void

    @Environment(PlayerViewModel.self) private var playerVM

    private var isCurrentSong: Bool {
        playerVM.audioPlayer.currentSong?.id == song.id
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // 序号 / 正在播放动画
                Group {
                    if isCurrentSong && playerVM.audioPlayer.isPlaying {
                        Image(systemName: "waveform")
                            .symbolEffect(.variableColor.iterative)
                            .foregroundStyle(Color(hex: song.platform.iconColor) ?? .accentColor)
                    } else if isCurrentSong {
                        Image(systemName: "pause.fill")
                            .foregroundStyle(Color(hex: song.platform.iconColor) ?? .accentColor)
                    } else {
                        Text("\(index)")
                            .foregroundStyle(.tertiary)
                    }
                }
                .font(.caption)
                .frame(width: 24)

                // 封面
                AlbumArtView(platform: song.platform, size: 44, cornerRadius: 8)

                // 歌曲信息
                VStack(alignment: .leading, spacing: 3) {
                    Text(song.name)
                        .font(.body)
                        .fontWeight(isCurrentSong ? .semibold : .regular)
                        .foregroundStyle(isCurrentSong ? Color(hex: song.platform.iconColor) ?? .accentColor : .primary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        PlatformBadge(platform: song.platform, compact: true)
                        Text("\(song.artist) · \(song.album)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // 时长
                Text(song.durationText)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background {
                if isCurrentSong {
                    RoundedRectangle(cornerRadius: DesignTokens.radiusSM)
                        .fill((Color(hex: song.platform.iconColor) ?? .accentColor).opacity(0.08))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
