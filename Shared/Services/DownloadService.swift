import Foundation
import Combine

/// 下载任务状态
enum DownloadState: String {
    case waiting = "等待中"
    case downloading = "下载中"
    case completed = "已完成"
    case failed = "失败"
}

/// 下载任务
@Observable
class DownloadTask: Identifiable {
    let id = UUID()
    let song: Song
    var state: DownloadState = .waiting
    var progress: Double = 0
    var filePath: String?
    var error: String?

    init(song: Song) {
        self.song = song
    }
}

/// 下载服务
@MainActor @Observable
final class DownloadService {
    var tasks: [DownloadTask] = []
    var downloadPath: String

    private var engine: MusicSourceEngine?
    private let maxConcurrent = 3

    init() {
        // 默认下载到 ~/Music/MusicBox
        let musicDir = FileManager.default.urls(for: .musicDirectory, in: .userDomainMask).first!
        downloadPath = musicDir.appendingPathComponent("MusicBox").path
    }

    func setEngine(_ engine: MusicSourceEngine) {
        self.engine = engine
    }

    func download(_ song: Song) {
        guard !tasks.contains(where: { $0.song.id == song.id && $0.state != .failed }) else { return }
        let task = DownloadTask(song: song)
        tasks.insert(task, at: 0)
        Task { await processTask(task) }
    }

    func downloadAll(_ songs: [Song]) {
        for song in songs { download(song) }
    }

    func removeTask(_ task: DownloadTask) {
        tasks.removeAll { $0.id == task.id }
    }

    func clearCompleted() {
        tasks.removeAll { $0.state == .completed }
    }

    func retryFailed(_ task: DownloadTask) {
        task.state = .waiting
        task.progress = 0
        task.error = nil
        Task { await processTask(task) }
    }

    private func processTask(_ task: DownloadTask) async {
        guard let engine = engine else {
            task.state = .failed
            task.error = "引擎未初始化"
            return
        }

        task.state = .downloading
        task.progress = 0.1

        do {
            // 获取播放链接
            let urlString = try await engine.getSongUrl(song: task.song)
            guard let url = URL(string: urlString) else {
                task.state = .failed
                task.error = "无效的 URL"
                return
            }

            task.progress = 0.3

            // 创建下载目录
            let dir = URL(fileURLWithPath: downloadPath)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

            // 下载
            let (data, response) = try await URLSession.shared.data(from: url)
            task.progress = 0.8

            // 确定文件扩展名
            let ext: String
            if let mimeType = (response as? HTTPURLResponse)?.mimeType {
                switch mimeType {
                case "audio/flac": ext = "flac"
                case "audio/ogg": ext = "ogg"
                case "audio/wav": ext = "wav"
                default: ext = "mp3"
                }
            } else {
                ext = "mp3"
            }

            // 文件名: 歌手 - 歌名.ext
            let safeName = "\(task.song.artist) - \(task.song.name)"
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: ":", with: "_")
            let filePath = dir.appendingPathComponent("\(safeName).\(ext)")

            try data.write(to: filePath)
            task.progress = 1.0
            task.state = .completed
            task.filePath = filePath.path
            print("[Download] 下载完成: \(filePath.lastPathComponent)")
        } catch {
            task.state = .failed
            task.error = error.localizedDescription
            print("[Download] 下载失败: \(error)")
        }
    }
}
