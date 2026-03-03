import SwiftUI

// MARK: - 搜索页

struct SearchView: View {
    @Environment(SearchViewModel.self) private var searchVM
    @Environment(PlayerViewModel.self) private var playerVM
    @Environment(MusicSourceEngine.self) private var engine

    var body: some View {
        @Bindable var vm = searchVM
        ZStack {
            // 背景
            #if os(iOS)
            Color(.systemGroupedBackground).ignoresSafeArea()
            #endif

            VStack(spacing: 0) {
                // 搜索区域
                VStack(spacing: 12) {
                    searchBar
                    platformChips
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 14)

                // 内容
                Group {
                    if searchVM.isSearching {
                        loadingView
                    } else if let err = searchVM.errorMessage {
                        emptyView(icon: "exclamationmark.triangle.fill", text: "出错了", sub: err, color: .orange)
                    } else if searchVM.results.isEmpty && !searchVM.keyword.isEmpty {
                        emptyView(icon: "magnifyingglass", text: "暂无结果", sub: "试试换个关键词", color: .secondary)
                    } else if searchVM.results.isEmpty {
                        if engine.isLoaded {
                            emptyView(icon: "music.magnifyingglass", text: "搜索音乐", sub: "输入关键词开始搜索", color: .purple)
                        } else {
                            emptyView(icon: "square.and.arrow.down", text: "添加音源", sub: "前往「设置」添加音源订阅地址", color: .orange)
                        }
                    } else {
                        resultsList
                    }
                }
            }
        }
        .navigationTitle("搜索")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
    }

    // MARK: - 搜索框

    private var searchBar: some View {
        @Bindable var vm = searchVM
        return HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("歌曲、歌手、专辑", text: $vm.keyword)
                    .textFieldStyle(.plain)
                    .onSubmit { Task { await searchVM.search(engine: engine) } }

                if !searchVM.keyword.isEmpty {
                    Button { searchVM.clear() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.quaternary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            if !searchVM.keyword.isEmpty {
                Button {
                    Task { await searchVM.search(engine: engine) }
                } label: {
                    Text("搜索")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.purple)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.3), value: searchVM.keyword.isEmpty)
    }

    // MARK: - 平台标签

    private var platformChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chipButton("全部", isSelected: searchVM.selectedPlatform == nil, color: .purple) {
                    searchVM.selectedPlatform = nil
                    if !searchVM.keyword.isEmpty { Task { await searchVM.search(engine: engine) } }
                }
                ForEach(MusicPlatform.allCases) { p in
                    chipButton(p.displayName, isSelected: searchVM.selectedPlatform == p, color: DS.color(for: p)) {
                        searchVM.selectedPlatform = p
                        if !searchVM.keyword.isEmpty { Task { await searchVM.search(engine: engine) } }
                    }
                }
            }
        }
    }

    private func chipButton(_ title: String, isSelected: Bool, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(isSelected ? .bold : .regular))
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? color : Color(.secondarySystemFill))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.15), value: isSelected)
    }

    // MARK: - 加载

    private var loadingView: some View {
        VStack(spacing: 12) {
            Spacer()
            ProgressView()
                .scaleEffect(1.2)
            Text("搜索中...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    // MARK: - 空状态

    private func emptyView(icon: String, text: String, sub: String, color: Color) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 50, weight: .light))
                .foregroundStyle(color.opacity(0.5))
                .symbolRenderingMode(.hierarchical)
            Text(text)
                .font(.title3.bold())
            Text(sub)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    // MARK: - 结果列表

    private var resultsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(searchVM.results.enumerated()), id: \.element.id) { idx, song in
                    SongRow(song: song, index: idx + 1) {
                        Task {
                            await playerVM.playSongFromSearchResult(
                                song, allResults: searchVM.results, engine: engine
                            )
                        }
                    }

                    if idx < searchVM.results.count - 1 {
                        Divider().padding(.leading, 76)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
}

// MARK: - 歌曲行

struct SongRow: View {
    let song: Song
    var index: Int = 0
    let onTap: () -> Void
    @Environment(PlayerViewModel.self) private var playerVM

    private var isPlaying: Bool {
        playerVM.audioPlayer.currentSong?.id == song.id
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // 封面
                ZStack {
                    AlbumCover(platform: song.platform, size: 50, isCircle: false)

                    if isPlaying {
                        RoundedRectangle(cornerRadius: 9)
                            .fill(.black.opacity(0.35))
                            .frame(width: 50, height: 50)
                        Image(systemName: playerVM.audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                            .font(.callout)
                            .foregroundStyle(.white)
                    }
                }

                // 信息
                VStack(alignment: .leading, spacing: 4) {
                    Text(song.name)
                        .font(.body.weight(isPlaying ? .semibold : .regular))
                        .foregroundStyle(isPlaying ? DS.color(for: song.platform) : .primary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        PlatformTag(platform: song.platform, small: true)
                        Text(song.artist)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)

                // 时长
                Text(song.durationText)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
