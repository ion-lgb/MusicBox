import SwiftUI

// MARK: - 迷你播放条

struct MiniPlayerView: View {
    @Environment(PlayerViewModel.self) private var playerVM
    @Environment(MusicSourceEngine.self) private var engine

    private var player: AudioPlayerService { playerVM.audioPlayer }

    var body: some View {
        if let song = player.currentSong {
            VStack(spacing: 0) {
                // 细进度条
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(.white.opacity(0.08))
                        Rectangle()
                            .fill(DS.color(for: song.platform))
                            .frame(width: geo.size.width * player.progress)
                            .animation(.linear(duration: 0.5), value: player.progress)
                    }
                }
                .frame(height: 3)

                // 播放条内容
                HStack(spacing: 12) {
                    AlbumCover(platform: song.platform, size: 44, isCircle: true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(song.name)
                            .font(.subheadline.weight(.medium))
                            .lineLimit(1)
                        Text(song.artist)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    // 控制按钮
                    HStack(spacing: 18) {
                        Button { Task { await playerVM.playPrevious(engine: engine) } } label: {
                            Image(systemName: "backward.fill")
                                .font(.body)
                        }

                        if playerVM.isLoadingUrl {
                            ProgressView()
                                .frame(width: 34, height: 34)
                        } else {
                            Button { playerVM.togglePlayPause() } label: {
                                Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                    .font(.system(size: 34))
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(.white, DS.color(for: song.platform))
                            }
                        }

                        Button { Task { await playerVM.playNext(engine: engine) } } label: {
                            Image(systemName: "forward.fill")
                                .font(.body)
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.primary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .background(.ultraThinMaterial)
            #if os(iOS)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.15), radius: 10, y: -2)
            .padding(.horizontal, 8)
            .padding(.bottom, 2)
            .onTapGesture { playerVM.showFullPlayer = true }
            #endif
        }
    }
}

// MARK: - 全屏播放器

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
                // 模糊渐变背景
                themeColor
                    .ignoresSafeArea()
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
                        AlbumCover(platform: song.platform, size: 260, isCircle: true)
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
            // 拖拽关闭
            .gesture(
                DragGesture()
                    .onChanged { v in
                        dragOffset = max(0, v.translation.height)
                    }
                    .onEnded { v in
                        if v.translation.height > geometry.size.height / 4 {
                            withAnimation(.spring()) {
                                dragOffset = geometry.size.height
                                dismiss()
                            }
                        } else {
                            withAnimation(.spring()) { dragOffset = 0 }
                        }
                    }
            )
        }
        .ignoresSafeArea()
    }
}
