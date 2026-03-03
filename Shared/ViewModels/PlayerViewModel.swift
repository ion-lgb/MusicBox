import Foundation
import Combine

/// 播放器 ViewModel
@MainActor @Observable
final class PlayerViewModel {
    let audioPlayer = AudioPlayerService()

    // 歌词
    var lyricText: String = ""
    var lyricLines: [LyricLine] = []
    var currentLyricIndex: Int = -1

    // UI 状态
    var isLoadingUrl = false
    var showFullPlayer = false
    var showLyricPanel = false
    var showPlayQueue = false
    var playError: String?

    private var cancellables = Set<AnyCancellable>()
    private var lyricTimer: Timer?

    init() {
        setupNotifications()
        startLyricTimer()
    }

    // MARK: - 播放

    func playSong(_ song: Song, engine: MusicSourceEngine) async {
        isLoadingUrl = true
        playError = nil
        audioPlayer.currentSong = song

        do {
            print("[Player] 正在获取播放链接: \(song.name) - \(song.artist)")
            let url = try await engine.getSongUrl(song: song)
            print("[Player] 获取到播放链接: \(url.prefix(80))...")
            audioPlayer.play(song: song, urlString: url)
            isLoadingUrl = false

            // 异步加载歌词
            Task {
                let lyric = await engine.getLyric(song: song)
                self.lyricText = lyric
                self.lyricLines = LyricParser.parse(lyric)
                self.currentLyricIndex = -1
                print("[Player] 歌词加载完成: \(self.lyricLines.count) 行")
            }
        } catch {
            isLoadingUrl = false
            playError = error.localizedDescription
            print("[Player] 播放失败: \(error)")
            Task {
                try? await Task.sleep(for: .seconds(3))
                self.playError = nil
            }
        }
    }

    func playSongFromSearchResult(_ song: Song, allResults: [Song], engine: MusicSourceEngine) async {
        audioPlayer.setQueue(allResults, startIndex: allResults.firstIndex(of: song) ?? 0)
        await playSong(song, engine: engine)
    }

    // MARK: - 控制

    func togglePlayPause() {
        audioPlayer.togglePlayPause()
    }

    func playNext(engine: MusicSourceEngine) async {
        guard let song = audioPlayer.nextSong() else { return }
        await playSong(song, engine: engine)
    }

    func playPrevious(engine: MusicSourceEngine) async {
        guard let song = audioPlayer.previousSong() else { return }
        await playSong(song, engine: engine)
    }

    func seek(to progress: Double) {
        audioPlayer.seek(to: progress)
    }

    // MARK: - 歌词同步

    private func startLyricTimer() {
        lyricTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, !self.lyricLines.isEmpty else { return }
                let newIndex = LyricParser.currentIndex(for: self.audioPlayer.currentTime, in: self.lyricLines)
                if newIndex != self.currentLyricIndex {
                    self.currentLyricIndex = newIndex
                }
            }
        }
    }

    // MARK: - Notifications

    private func setupNotifications() {
        NotificationCenter.default.publisher(for: .playerDidFinishPlaying)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.audioPlayer.isPlaying = false
            }
            .store(in: &cancellables)
    }
}
