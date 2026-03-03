import Foundation
import Combine

/// 播放器 ViewModel
@MainActor @Observable
final class PlayerViewModel {
    let audioPlayer = AudioPlayerService()
    var lyricText: String = ""
    var isLoadingUrl = false
    var showFullPlayer = false

    private var cancellables = Set<AnyCancellable>()

    init() {
        setupNotifications()
    }

    // MARK: - 播放

    func playSong(_ song: Song, engine: MusicSourceEngine) async {
        isLoadingUrl = true
        do {
            let url = try await engine.getSongUrl(song: song)
            audioPlayer.play(song: song, urlString: url)
            isLoadingUrl = false
            // 异步加载歌词
            let lyric = try? await engine.getLyric(song: song)
            self.lyricText = lyric ?? ""
        } catch {
            isLoadingUrl = false
            print("Play error:", error)
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
