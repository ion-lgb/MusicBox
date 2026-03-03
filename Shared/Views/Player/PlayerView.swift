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
                            .fill(Color.secondary.opacity(0.15))
                        Rectangle()
                            .fill(Color.accentColor)
                            .frame(width: geo.size.width * player.progress)
                    }
                }
                .frame(height: 3)

                HStack(spacing: 14) {
                    // 封面占位
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(hex: song.platform.iconColor) ?? .gray,
                                    Color(hex: song.platform.iconColor)?.opacity(0.6) ?? .gray
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                        .overlay {
                            Image(systemName: "music.note")
                                .foregroundStyle(.white)
                                .font(.title3)
                        }

                    // 歌曲信息
                    VStack(alignment: .leading, spacing: 2) {
                        Text(song.name)
                            .font(.callout.weight(.medium))
                            .lineLimit(1)
                        Text(song.artist)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    // 播放控制
                    HStack(spacing: 18) {
                        Button {
                            Task { await playerVM.playPrevious(engine: engine) }
                        } label: {
                            Image(systemName: "backward.fill")
                                .font(.title3)
                        }
                        .buttonStyle(.plain)

                        Button {
                            playerVM.togglePlayPause()
                        } label: {
                            Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                .font(.title2)
                                .frame(width: 36, height: 36)
                                .background(Circle().fill(Color.accentColor))
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)

                        Button {
                            Task { await playerVM.playNext(engine: engine) }
                        } label: {
                            Image(systemName: "forward.fill")
                                .font(.title3)
                        }
                        .buttonStyle(.plain)
                    }

                    #if os(iOS)
                    // iOS: 展开全屏播放器
                    Button {
                        playerVM.showFullPlayer = true
                    } label: {
                        Image(systemName: "chevron.up")
                            .font(.caption)
                            .padding(6)
                    }
                    .buttonStyle(.plain)
                    #endif
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .background(.ultraThinMaterial)
            #if os(iOS)
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
            VStack(spacing: 24) {
                Spacer()

                // 封面
                if let song = player.currentSong {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(hex: song.platform.iconColor) ?? .gray,
                                    Color(hex: song.platform.iconColor)?.opacity(0.4) ?? .gray
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 280, height: 280)
                        .overlay {
                            Image(systemName: "music.note")
                                .font(.system(size: 64))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        .shadow(color: (Color(hex: song.platform.iconColor) ?? .gray).opacity(0.4), radius: 20, y: 10)
                }

                // 歌曲信息
                VStack(spacing: 6) {
                    Text(player.currentSong?.name ?? "--")
                        .font(.title2.bold())
                        .lineLimit(1)
                    Text(player.currentSong?.artist ?? "--")
                        .font(.body)
                        .foregroundStyle(.secondary)
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
                    .tint(.accentColor)

                    HStack {
                        Text(formatTime(player.currentTime))
                        Spacer()
                        Text(formatTime(player.duration))
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                }
                .padding(.horizontal, 32)

                // 播放控制
                HStack(spacing: 36) {
                    Button {
                        player.playMode = PlayMode.allCases[
                            (PlayMode.allCases.firstIndex(of: player.playMode)! + 1) % PlayMode.allCases.count
                        ]
                    } label: {
                        Image(systemName: player.playMode.icon)
                            .font(.title3)
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
                            .font(.system(size: 64))
                    }

                    Button {
                        Task { await playerVM.playNext(engine: engine) }
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.title)
                    }

                    Button {
                        // TODO: 显示播放队列
                    } label: {
                        Image(systemName: "list.bullet")
                            .font(.title3)
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.primary)

                Spacer()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.down")
                    }
                }
            }
        }
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%d:%02d", m, s)
    }
}
