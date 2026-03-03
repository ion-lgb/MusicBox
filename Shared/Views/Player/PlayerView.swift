import SwiftUI

/// 底部迷你播放条
struct MiniPlayerView: View {
    @Environment(PlayerViewModel.self) private var playerVM
    @Environment(MusicSourceEngine.self) private var engine

    private var player: AudioPlayerService { playerVM.audioPlayer }

    var body: some View {
        if let song = player.currentSong {
            VStack(spacing: 0) {
                // 进度条
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.primary.opacity(0.06))
                        Rectangle()
                            .fill(Color(hex: song.platform.iconColor) ?? .accentColor)
                            .frame(width: geo.size.width * player.progress)
                            .animation(.linear(duration: 0.3), value: player.progress)
                    }
                }
                .frame(height: 2.5)

                HStack(spacing: 14) {
                    // 封面
                    AlbumArtView(platform: song.platform, size: 46, cornerRadius: 10)
                        .shadow(color: (Color(hex: song.platform.iconColor) ?? .gray).opacity(0.3), radius: 6, y: 2)

                    // 歌曲信息
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

                    // 播放控制
                    HStack(spacing: 20) {
                        Button {
                            Task { await playerVM.playPrevious(engine: engine) }
                        } label: {
                            Image(systemName: "backward.fill")
                                .font(.callout)
                                .foregroundStyle(.primary)
                        }
                        .buttonStyle(.plain)

                        Button {
                            playerVM.togglePlayPause()
                        } label: {
                            Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                .font(.title3)
                                .frame(width: 38, height: 38)
                                .background(
                                    Circle().fill(Color(hex: song.platform.iconColor) ?? .accentColor)
                                )
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)

                        Button {
                            Task { await playerVM.playNext(engine: engine) }
                        } label: {
                            Image(systemName: "forward.fill")
                                .font(.callout)
                                .foregroundStyle(.primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .background(.ultraThinMaterial)
            #if os(iOS)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .shadow(color: .black.opacity(0.12), radius: 12, y: -2)
            .padding(.horizontal, 8)
            .padding(.bottom, 2)
            .onTapGesture {
                playerVM.showFullPlayer = true
            }
            #endif
        }
    }
}

/// 全屏播放器 (iOS)
struct FullPlayerView: View {
    @Environment(PlayerViewModel.self) private var playerVM
    @Environment(MusicSourceEngine.self) private var engine
    @Environment(\.dismiss) private var dismiss

    private var player: AudioPlayerService { playerVM.audioPlayer }

    var body: some View {
        NavigationStack {
            ZStack {
                // 背景
                if let song = player.currentSong {
                    (Color(hex: song.platform.iconColor) ?? Color.accentColor)
                        .opacity(0.1)
                        .ignoresSafeArea()
                }

                VStack(spacing: 28) {
                    Spacer()

                    // 封面
                    if let song = player.currentSong {
                        AlbumArtView(platform: song.platform, size: 260, cornerRadius: 24)
                            .shadow(color: (Color(hex: song.platform.iconColor) ?? .gray).opacity(0.35), radius: 30, y: 15)
                            .scaleEffect(player.isPlaying ? 1.0 : 0.92)
                            .animation(.spring(duration: 0.5), value: player.isPlaying)
                    }

                    // 歌曲信息
                    VStack(spacing: 6) {
                        Text(player.currentSong?.name ?? "--")
                            .font(.title2.bold())
                            .lineLimit(1)
                        HStack(spacing: 6) {
                            if let song = player.currentSong {
                                PlatformBadge(platform: song.platform)
                            }
                            Text(player.currentSong?.artist ?? "--")
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 32)

                    // 进度条
                    VStack(spacing: 4) {
                        Slider(
                            value: Binding(
                                get: { player.progress },
                                set: { playerVM.seek(to: $0) }
                            ),
                            in: 0...1
                        )
                        .tint(player.currentSong.flatMap { Color(hex: $0.platform.iconColor) } ?? .accentColor)

                        HStack {
                            Text(player.currentTime.formattedTime)
                            Spacer()
                            Text(player.duration.formattedTime)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    }
                    .padding(.horizontal, 36)

                    // 播放控制
                    HStack(spacing: 36) {
                        Button {
                            player.playMode = PlayMode.allCases[
                                (PlayMode.allCases.firstIndex(of: player.playMode)! + 1) % PlayMode.allCases.count
                            ]
                        } label: {
                            Image(systemName: player.playMode.icon)
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }

                        Button {
                            Task { await playerVM.playPrevious(engine: engine) }
                        } label: {
                            Image(systemName: "backward.fill")
                                .font(.title)
                        }

                        Button {
                            playerVM.togglePlayPause()
                        } label: {
                            Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 68))
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(player.currentSong.flatMap { Color(hex: $0.platform.iconColor) } ?? .accentColor)
                        }

                        Button {
                            Task { await playerVM.playNext(engine: engine) }
                        } label: {
                            Image(systemName: "forward.fill")
                                .font(.title)
                        }

                        Button {
                            // TODO: 播放队列
                        } label: {
                            Image(systemName: "list.bullet")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.primary)

                    Spacer()
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
