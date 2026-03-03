import SwiftUI

// MARK: - iOS 全屏播放详情页

#if os(iOS)
struct iOSPlayerDetailView: View {
    @Environment(PlayerViewModel.self) private var playerVM
    @Environment(MusicSourceEngine.self) private var engine
    @Environment(\.dismiss) private var dismiss

    @State private var showLyric = false
    @State private var dragOffset: CGFloat = 0

    private var player: AudioPlayerService { playerVM.audioPlayer }

    var body: some View {
        if let song = player.currentSong {
            ZStack {
                // 背景模糊封面
                backgroundBlur(song)

                VStack(spacing: 0) {
                    // 顶部栏
                    topBar(song)

                    // 内容区（封面 ↔ 歌词翻页）
                    TabView(selection: $showLyric) {
                        coverPage(song).tag(false)
                        lyricPage.tag(true)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .automatic))
                    .animation(.easeInOut(duration: 0.3), value: showLyric)

                    // 进度条
                    progressSection

                    // 控制区
                    controlSection

                    Spacer().frame(height: 30)
                }
            }
            .ignoresSafeArea()
            .statusBarHidden(true)
            .gesture(
                DragGesture(minimumDistance: 50)
                    .onChanged { value in
                        if value.translation.height > 0 {
                            dragOffset = value.translation.height
                        }
                    }
                    .onEnded { value in
                        if value.translation.height > 120 {
                            dismiss()
                        }
                        dragOffset = 0
                    }
            )
            .offset(y: dragOffset)
            .animation(.interactiveSpring, value: dragOffset)
        }
    }

    // MARK: - 背景

    private func backgroundBlur(_ song: Song) -> some View {
        ZStack {
            if let coverUrl = song.coverUrl, let url = URL(string: coverUrl) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        Color.black
                    }
                }
            } else {
                LinearGradient(
                    colors: [.purple.opacity(0.8), .black],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            Color.black.opacity(0.55)
            Rectangle().fill(.ultraThinMaterial).opacity(0.3)
        }
        .ignoresSafeArea()
    }

    // MARK: - 顶部栏

    private func topBar(_ song: Song) -> some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.down")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
            }
            Spacer()
            VStack(spacing: 2) {
                Text(song.name)
                    .font(.subheadline.bold())
                    .lineLimit(1)
                Text(song.artist)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
            }
            .foregroundStyle(.white)
            Spacer()
            // 播放队列按钮
            Button {
                playerVM.showPlayQueue.toggle()
            } label: {
                Image(systemName: "list.bullet")
                    .font(.title3)
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 60)
        .padding(.bottom, 10)
    }

    // MARK: - 封面页

    private func coverPage(_ song: Song) -> some View {
        VStack(spacing: 24) {
            Spacer()
            // 大封面
            if let coverUrl = song.coverUrl, let url = URL(string: coverUrl) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: .black.opacity(0.5), radius: 20, y: 10)
                    } else {
                        albumPlaceholder
                    }
                }
                .frame(width: 300, height: 300)
            } else {
                albumPlaceholder
            }

            // 歌曲信息
            VStack(spacing: 6) {
                Text(song.name)
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                Text(song.artist)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
                if !song.album.isEmpty {
                    Text(song.album)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 40)

            Spacer()
        }
    }

    private var albumPlaceholder: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(
                LinearGradient(
                    colors: [.purple.opacity(0.6), .blue.opacity(0.4)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 300, height: 300)
            .overlay {
                Image(systemName: "music.note")
                    .font(.system(size: 80))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .shadow(color: .black.opacity(0.5), radius: 20, y: 10)
    }

    // MARK: - 歌词页

    private var lyricPage: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    Spacer().frame(height: 40)
                    if playerVM.lyricLines.isEmpty {
                        Text("暂无歌词")
                            .foregroundStyle(.white.opacity(0.5))
                            .padding(.top, 100)
                    } else {
                        ForEach(Array(playerVM.lyricLines.enumerated()), id: \.offset) { index, line in
                            VStack(spacing: 4) {
                                Text(line.text)
                                    .font(index == playerVM.currentLyricIndex ? .title3.bold() : .body)
                                    .foregroundStyle(index == playerVM.currentLyricIndex ? .white : .white.opacity(0.4))
                                    .multilineTextAlignment(.center)

                                if let translation = line.translation {
                                    Text(translation)
                                        .font(.caption)
                                        .foregroundStyle(index == playerVM.currentLyricIndex ? .white.opacity(0.8) : .white.opacity(0.3))
                                }
                            }
                            .id(index)
                            .padding(.horizontal, 30)
                            .animation(.easeOut(duration: 0.3), value: playerVM.currentLyricIndex)
                        }
                    }
                    Spacer().frame(height: 40)
                }
            }
            .onChange(of: playerVM.currentLyricIndex) { _, newIndex in
                withAnimation(.easeInOut(duration: 0.3)) {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
        }
    }

    // MARK: - 进度条

    private var progressSection: some View {
        VStack(spacing: 4) {
            Slider(
                value: Binding(
                    get: { player.progress },
                    set: { playerVM.seek(to: $0) }
                ),
                in: 0...1
            )
            .tint(.white)

            HStack {
                Text(formatTime(player.currentTime))
                Spacer()
                Text(formatTime(player.duration))
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(.white.opacity(0.6))
        }
        .padding(.horizontal, 30)
    }

    // MARK: - 控制区

    private var controlSection: some View {
        HStack(spacing: 0) {
            // 播放模式
            Button {
                let modes = PlayMode.allCases
                if let idx = modes.firstIndex(of: player.playMode) {
                    player.playMode = modes[(idx + 1) % modes.count]
                }
            } label: {
                Image(systemName: player.playMode.icon)
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .frame(maxWidth: .infinity)

            // 上一首
            Button {
                Task { await playerVM.playPrevious(engine: engine) }
            } label: {
                Image(systemName: "backward.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)

            // 播放/暂停
            Button {
                playerVM.togglePlayPause()
            } label: {
                Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)

            // 下一首
            Button {
                Task { await playerVM.playNext(engine: engine) }
            } label: {
                Image(systemName: "forward.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)

            // 播放队列
            Button {
                playerVM.showPlayQueue.toggle()
            } label: {
                Image(systemName: "list.bullet")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 10)
        .padding(.top, 16)
    }

    // MARK: - 工具

    private func formatTime(_ seconds: TimeInterval) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%d:%02d", m, s)
    }
}
#endif
