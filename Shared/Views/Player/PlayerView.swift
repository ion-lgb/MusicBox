import SwiftUI

// MARK: - macOS 底部播放条

struct MiniPlayerView: View {
    @Environment(PlayerViewModel.self) private var playerVM
    @Environment(MusicSourceEngine.self) private var engine

    private var player: AudioPlayerService { playerVM.audioPlayer }

    var body: some View {
        if let song = player.currentSong {
            VStack(spacing: 0) {
                // 顶部进度条（可拖拽）
                ProgressSlider(
                    value: Binding(get: { player.progress }, set: { playerVM.seek(to: $0) }),
                    platform: song.platform
                )

                // 播放条内容
                HStack(spacing: 0) {
                    // 左侧：封面 + 歌曲信息
                    songInfoSection(song)

                    Spacer()

                    // 中间：播放控制
                    controlSection(song)

                    Spacer()

                    // 右侧：音量 + 模式 + 歌词按钮
                    rightSection(song)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .background(.ultraThinMaterial)
            .frame(height: 72)
        }
    }

    // MARK: - 左侧歌曲信息

    private func songInfoSection(_ song: Song) -> some View {
        HStack(spacing: 12) {
            AlbumCover(platform: song.platform, size: 48, isCircle: false, coverUrl: song.coverUrl)

            VStack(alignment: .leading, spacing: 3) {
                Text(song.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                HStack(spacing: 5) {
                    PlatformTag(platform: song.platform, small: true)
                    Text(song.artist)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: 200, alignment: .leading)
        }
    }

    // MARK: - 中间播放控制

    private func controlSection(_ song: Song) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 24) {
                // 上一首
                Button { Task { await playerVM.playPrevious(engine: engine) } } label: {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)

                // 播放/暂停
                if playerVM.isLoadingUrl {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 36, height: 36)
                } else {
                    Button { playerVM.togglePlayPause() } label: {
                        Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 36))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.primary, DS.color(for: song.platform).opacity(0.9))
                    }
                    .buttonStyle(.plain)
                }

                // 下一首
                Button { Task { await playerVM.playNext(engine: engine) } } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
            }

            // 时间显示
            HStack(spacing: 4) {
                Text(player.currentTime.formattedTime)
                Text("/")
                Text(player.duration.formattedTime)
            }
            .font(.system(size: 10))
            .monospacedDigit()
            .foregroundStyle(.tertiary)
        }
    }

    // MARK: - 右侧控制

    private func rightSection(_ song: Song) -> some View {
        HStack(spacing: 14) {
            // 音量
            HStack(spacing: 6) {
                Image(systemName: player.volume == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .onTapGesture {
                        player.volume = player.volume == 0 ? 0.8 : 0
                    }
                Slider(value: Binding(get: { Double(player.volume) }, set: { player.volume = Float($0) }), in: 0...1)
                    .frame(width: 70)
                    .controlSize(.mini)
            }

            // 播放模式
            Button {
                player.playMode = PlayMode.allCases[
                    (PlayMode.allCases.firstIndex(of: player.playMode)! + 1) % PlayMode.allCases.count
                ]
            } label: {
                Image(systemName: player.playMode.icon)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .help(player.playMode.rawValue)
            }
            .buttonStyle(.plain)

            // 歌词按钮
            Button {
                withAnimation(.spring(duration: 0.3)) {
                    playerVM.showLyricPanel.toggle()
                }
            } label: {
                Image(systemName: "quote.bubble")
                    .font(.system(size: 13))
                    .foregroundStyle(playerVM.showLyricPanel ? DS.color(for: song.platform) : .secondary)
            }
            .buttonStyle(.plain)

            // 播放列表
            Button {
                withAnimation(.spring(duration: 0.3)) {
                    playerVM.showPlayQueue.toggle()
                }
            } label: {
                Image(systemName: "list.bullet")
                    .font(.system(size: 13))
                    .foregroundStyle(playerVM.showPlayQueue ? DS.color(for: song.platform) : .secondary)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - 可交互进度条

struct ProgressSlider: View {
    @Binding var value: Double
    let platform: MusicPlatform
    @State private var isHovering = false
    @State private var isDragging = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // 背景轨道
                Rectangle()
                    .fill(.white.opacity(0.08))

                // 进度填充
                Rectangle()
                    .fill(DS.color(for: platform))
                    .frame(width: geo.size.width * value)

                // 拖拽指示器
                if isHovering || isDragging {
                    Circle()
                        .fill(DS.color(for: platform))
                        .frame(width: 12, height: 12)
                        .shadow(radius: 2)
                        .position(x: geo.size.width * value, y: geo.size.height / 2)
                }
            }
            .frame(height: isHovering || isDragging ? 6 : 3)
            .animation(.easeInOut(duration: 0.15), value: isHovering)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        isDragging = true
                        value = max(0, min(1, v.location.x / geo.size.width))
                    }
                    .onEnded { _ in isDragging = false }
            )
            .onHover { isHovering = $0 }
        }
        .frame(height: isHovering || isDragging ? 6 : 3)
    }
}

// MARK: - 歌词面板

struct LyricPanelView: View {
    @Environment(PlayerViewModel.self) private var playerVM
    private var player: AudioPlayerService { playerVM.audioPlayer }

    var body: some View {
        VStack(spacing: 0) {
            // 顶部标题栏
            HStack {
                if let song = player.currentSong {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(song.name)
                            .font(.title3.bold())
                        Text(song.artist)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button {
                    withAnimation(.spring(duration: 0.3)) {
                        playerVM.showLyricPanel = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 12)

            Divider()

            // 歌词内容
            if playerVM.lyricLines.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "music.note")
                        .font(.system(size: 40))
                        .foregroundStyle(.quaternary)
                    Text("暂无歌词")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            Spacer().frame(height: 60)
                            ForEach(Array(playerVM.lyricLines.enumerated()), id: \.element.id) { index, line in
                                LyricLineView(
                                    line: line,
                                    isCurrent: index == playerVM.currentLyricIndex,
                                    platform: player.currentSong?.platform ?? .netease
                                )
                                .id(index)
                            }
                            Spacer().frame(height: 120)
                        }
                        .padding(.horizontal, 32)
                    }
                    .onChange(of: playerVM.currentLyricIndex) { _, newIndex in
                        guard newIndex >= 0 else { return }
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(newIndex, anchor: .center)
                        }
                    }
                }
            }
        }
        .background(.ultraThinMaterial)
    }
}

// MARK: - 单行歌词

struct LyricLineView: View {
    let line: LyricLine
    let isCurrent: Bool
    let platform: MusicPlatform

    var body: some View {
        VStack(spacing: 4) {
            Text(line.text)
                .font(.system(size: isCurrent ? 18 : 15, weight: isCurrent ? .bold : .regular))
                .foregroundStyle(isCurrent ? DS.color(for: platform) : .secondary)
                .multilineTextAlignment(.center)

            if let trans = line.translation, !trans.isEmpty {
                Text(trans)
                    .font(.system(size: isCurrent ? 14 : 12))
                    .foregroundStyle(isCurrent ? DS.color(for: platform).opacity(0.7) : Color.secondary.opacity(0.5))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .opacity(isCurrent ? 1.0 : 0.6)
        .scaleEffect(isCurrent ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.25), value: isCurrent)
    }
}

// MARK: - 播放队列面板

struct PlayQueueView: View {
    @Environment(PlayerViewModel.self) private var playerVM
    @Environment(MusicSourceEngine.self) private var engine
    private var player: AudioPlayerService { playerVM.audioPlayer }

    var body: some View {
        VStack(spacing: 0) {
            // 标题
            HStack {
                Text("播放队列")
                    .font(.title3.bold())
                Spacer()
                Text("\(player.queue.count) 首")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                Button {
                    withAnimation(.spring(duration: 0.3)) {
                        playerVM.showPlayQueue = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 8)

            Divider()

            // 歌曲列表
            if player.queue.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "music.note.list")
                        .font(.system(size: 40))
                        .foregroundStyle(.quaternary)
                    Text("播放队列为空")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else {
                ScrollViewReader { proxy in
                    List {
                        ForEach(Array(player.queue.enumerated()), id: \.element.id) { index, song in
                            HStack(spacing: 10) {
                                // 当前播放指示
                                if index == player.currentIndex {
                                    Image(systemName: "speaker.wave.2.fill")
                                        .font(.caption)
                                        .foregroundStyle(DS.color(for: song.platform))
                                        .frame(width: 16)
                                } else {
                                    Text("\(index + 1)")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                        .frame(width: 16)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(song.name)
                                        .font(.system(size: 13, weight: index == player.currentIndex ? .semibold : .regular))
                                        .foregroundStyle(index == player.currentIndex ? DS.color(for: song.platform) : .primary)
                                        .lineLimit(1)
                                    Text(song.artist)
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }

                                Spacer()

                                PlatformTag(platform: song.platform, small: true)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                Task {
                                    if let s = player.playFromQueue(index: index) {
                                        await playerVM.playSong(s, engine: engine)
                                    }
                                }
                            }
                            .id(index)
                        }
                    }
                    .listStyle(.plain)
                    .onAppear {
                        if player.currentIndex >= 0 {
                            proxy.scrollTo(player.currentIndex, anchor: .center)
                        }
                    }
                }
            }
        }
        .background(.ultraThinMaterial)
    }
}

// MARK: - macOS 全屏播放器 (已弃用 iOS sheet，macOS 用歌词面板代替)

#if os(iOS)
struct FullPlayerView: View {
    @Environment(PlayerViewModel.self) private var playerVM
    @Environment(MusicSourceEngine.self) private var engine
    @Environment(\.dismiss) private var dismiss

    private var player: AudioPlayerService { playerVM.audioPlayer }
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        let song = player.currentSong
        let themeColor = song.map { DS.color(for: $0.platform) } ?? .purple

        GeometryReader { geometry in
            ZStack {
                themeColor.ignoresSafeArea()
                    .overlay(Color.black.opacity(0.4))

                VStack(spacing: 0) {
                    // 拖拽手柄
                    RoundedRectangle(cornerRadius: 3)
                        .fill(.white.opacity(0.4))
                        .frame(width: 40, height: 5)
                        .padding(.top, 14)
                        .padding(.bottom, 30)

                    Spacer()

                    // 封面
                    if let song = song {
                        AlbumCover(platform: song.platform, size: 260, isCircle: true, coverUrl: song.coverUrl)
                            .scaleEffect(player.isPlaying ? 1.0 : 0.85)
                            .animation(.spring(duration: 0.5, bounce: 0.3), value: player.isPlaying)
                    }

                    Spacer().frame(height: 36)

                    // 歌曲信息
                    VStack(spacing: 6) {
                        Text(song?.name ?? "--")
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        HStack(spacing: 6) {
                            if let song = song { PlatformTag(platform: song.platform) }
                            Text(song?.artist ?? "--")
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .font(.subheadline)
                    }
                    .padding(.horizontal, 40)

                    Spacer().frame(height: 32)

                    // 进度条
                    VStack(spacing: 6) {
                        Slider(
                            value: Binding(get: { player.progress }, set: { playerVM.seek(to: $0) }),
                            in: 0...1
                        )
                        .tint(.white)

                        HStack {
                            Text(player.currentTime.formattedTime)
                            Spacer()
                            Text(player.duration.formattedTime)
                        }
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.5))
                    }
                    .padding(.horizontal, 32)

                    Spacer().frame(height: 28)

                    // 控制按钮
                    HStack(spacing: 40) {
                        Button {
                            player.playMode = PlayMode.allCases[
                                (PlayMode.allCases.firstIndex(of: player.playMode)! + 1) % PlayMode.allCases.count
                            ]
                        } label: {
                            Image(systemName: player.playMode.icon)
                                .font(.title3)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        Button { Task { await playerVM.playPrevious(engine: engine) } } label: {
                            Image(systemName: "backward.fill")
                                .font(.title)
                                .foregroundStyle(.white)
                        }
                        Button { playerVM.togglePlayPause() } label: {
                            Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                .font(.largeTitle)
                                .foregroundStyle(.white)
                                .frame(width: 70, height: 70)
                                .background(.white.opacity(0.15))
                                .clipShape(Circle())
                        }
                        Button { Task { await playerVM.playNext(engine: engine) } } label: {
                            Image(systemName: "forward.fill")
                                .font(.title)
                                .foregroundStyle(.white)
                        }
                        Button {} label: {
                            Image(systemName: "list.bullet")
                                .font(.title3)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
                .offset(y: dragOffset)
            }
            .gesture(
                DragGesture()
                    .onChanged { v in dragOffset = max(0, v.translation.height) }
                    .onEnded { v in
                        if v.translation.height > geometry.size.height / 4 {
                            withAnimation(.spring()) { dragOffset = geometry.size.height; dismiss() }
                        } else {
                            withAnimation(.spring()) { dragOffset = 0 }
                        }
                    }
            )
        }
        .ignoresSafeArea()
    }
}
#endif
