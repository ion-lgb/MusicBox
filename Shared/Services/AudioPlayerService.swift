import Foundation
import AVFoundation
import MediaPlayer

/// 播放模式
enum PlayMode: String, CaseIterable {
    case sequential = "顺序播放"
    case loop = "列表循环"
    case singleLoop = "单曲循环"
    case shuffle = "随机播放"

    var icon: String {
        switch self {
        case .sequential: return "arrow.right"
        case .loop: return "repeat"
        case .singleLoop: return "repeat.1"
        case .shuffle: return "shuffle"
        }
    }
}

/// 播放器服务 - AVPlayer 封装
@Observable
final class AudioPlayerService {
    private var player: AVPlayer?
    private var timeObserver: Any?

    // 播放状态
    var isPlaying = false
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 0
    var progress: Double {
        guard duration > 0 else { return 0 }
        return currentTime / duration
    }

    // 播放队列
    var currentSong: Song?
    var queue: [Song] = []
    var currentIndex: Int = -1
    var playMode: PlayMode = .loop

    // 音量
    var volume: Float = 0.8 {
        didSet { player?.volume = volume }
    }

    init() {
        setupAudioSession()
        setupRemoteCommands()
    }

    deinit {
        removeTimeObserver()
    }

    // MARK: - 播放控制

    func play(song: Song, url: URL) {
        removeTimeObserver()

        let item = AVPlayerItem(url: url)
        if player == nil {
            player = AVPlayer(playerItem: item)
        } else {
            player?.replaceCurrentItem(with: item)
        }

        player?.volume = volume
        player?.play()
        isPlaying = true
        currentSong = song

        addTimeObserver()
        observePlayerEnd(item: item)
        updateNowPlayingInfo()
    }

    func play(song: Song, urlString: String) {
        guard let url = URL(string: urlString) else { return }
        play(song: song, url: url)
    }

    func togglePlayPause() {
        guard player != nil else { return }
        if isPlaying {
            player?.pause()
        } else {
            player?.play()
        }
        isPlaying.toggle()
        updateNowPlayingInfo()
    }

    func pause() {
        player?.pause()
        isPlaying = false
        updateNowPlayingInfo()
    }

    func resume() {
        player?.play()
        isPlaying = true
        updateNowPlayingInfo()
    }

    func seek(to progress: Double) {
        let time = CMTime(seconds: duration * progress, preferredTimescale: 600)
        player?.seek(to: time) { [weak self] _ in
            self?.updateNowPlayingInfo()
        }
    }

    func seekForward(_ seconds: Double = 10) {
        let newTime = min(currentTime + seconds, duration)
        seek(to: newTime / max(duration, 1))
    }

    func seekBackward(_ seconds: Double = 10) {
        let newTime = max(currentTime - seconds, 0)
        seek(to: newTime / max(duration, 1))
    }

    // MARK: - 队列管理

    func playFromQueue(index: Int) -> Song? {
        guard index >= 0 && index < queue.count else { return nil }
        currentIndex = index
        return queue[index]
    }

    func nextSong() -> Song? {
        guard !queue.isEmpty else { return nil }
        switch playMode {
        case .sequential:
            if currentIndex < queue.count - 1 {
                currentIndex += 1
                return queue[currentIndex]
            }
            return nil
        case .loop:
            currentIndex = (currentIndex + 1) % queue.count
            return queue[currentIndex]
        case .singleLoop:
            return queue[currentIndex]
        case .shuffle:
            currentIndex = Int.random(in: 0..<queue.count)
            return queue[currentIndex]
        }
    }

    func previousSong() -> Song? {
        guard !queue.isEmpty else { return nil }
        if currentIndex > 0 {
            currentIndex -= 1
        } else {
            currentIndex = queue.count - 1
        }
        return queue[currentIndex]
    }

    func setQueue(_ songs: [Song], startIndex: Int = 0) {
        queue = songs
        currentIndex = startIndex
    }

    func addToQueue(_ song: Song) {
        queue.append(song)
        if currentIndex == -1 { currentIndex = 0 }
    }

    /// 插入到当前歌曲的下一首
    func insertNext(_ song: Song) {
        let insertAt = min(currentIndex + 1, queue.count)
        queue.insert(song, at: insertAt)
        if currentIndex == -1 { currentIndex = 0 }
    }

    // MARK: - 私有方法

    private func setupAudioSession() {
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {
            print("Audio session setup failed:", error)
        }
        #endif
    }

    private func addTimeObserver() {
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player?.addPeriodicTimeObserver(
            forInterval: interval,
            queue: .main
        ) { [weak self] time in
            guard let self = self else { return }
            self.currentTime = time.seconds
            if let item = self.player?.currentItem {
                let dur = item.duration.seconds
                if dur.isFinite && dur > 0 {
                    self.duration = dur
                }
            }
        }
    }

    private func removeTimeObserver() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
    }

    private func observePlayerEnd(item: AVPlayerItem) {
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            self?.isPlaying = false
            // 通知 ViewModel 播放下一首
            NotificationCenter.default.post(name: .playerDidFinishPlaying, object: nil)
        }
    }

    // MARK: - 系统集成 (Now Playing / 控制中心)

    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.addTarget { [weak self] _ in
            self?.resume()
            return .success
        }

        center.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }

        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }

        center.nextTrackCommand.addTarget { _ in
            NotificationCenter.default.post(name: .playerRequestNextTrack, object: nil)
            return .success
        }

        center.previousTrackCommand.addTarget { _ in
            NotificationCenter.default.post(name: .playerRequestPreviousTrack, object: nil)
            return .success
        }

        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let positionEvent = event as? MPChangePlaybackPositionCommandEvent,
                  let self = self else { return .commandFailed }
            let progress = positionEvent.positionTime / max(self.duration, 1)
            self.seek(to: progress)
            return .success
        }
    }

    private func updateNowPlayingInfo() {
        var info = [String: Any]()
        info[MPMediaItemPropertyTitle] = currentSong?.name ?? ""
        info[MPMediaItemPropertyArtist] = currentSong?.artist ?? ""
        info[MPMediaItemPropertyAlbumTitle] = currentSong?.album ?? ""
        info[MPMediaItemPropertyPlaybackDuration] = duration
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}

// MARK: - 通知名

extension Notification.Name {
    static let playerDidFinishPlaying = Notification.Name("playerDidFinishPlaying")
    static let playerRequestNextTrack = Notification.Name("playerRequestNextTrack")
    static let playerRequestPreviousTrack = Notification.Name("playerRequestPreviousTrack")
}
