import SwiftUI

// MARK: - 下载管理页面

struct DownloadView: View {
    @Environment(DownloadService.self) private var downloadService

    var body: some View {
        VStack(spacing: 0) {
            // 顶部操作栏
            HStack {
                Text("下载管理")
                    .font(.title2.bold())
                Spacer()

                if !downloadService.tasks.isEmpty {
                    Button {
                        downloadService.clearCompleted()
                    } label: {
                        Label("清除已完成", systemImage: "trash")
                            .font(.subheadline)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            // 下载路径
            HStack(spacing: 8) {
                Image(systemName: "folder.fill")
                    .foregroundStyle(.secondary)
                Text(downloadService.downloadPath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                #if os(macOS)
                Button("更改") {
                    let panel = NSOpenPanel()
                    panel.canChooseDirectories = true
                    panel.canChooseFiles = false
                    if panel.runModal() == .OK, let url = panel.url {
                        downloadService.downloadPath = url.path
                    }
                }
                .font(.caption)
                .buttonStyle(.plain)
                .foregroundStyle(.blue)
                #endif
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 10)

            Divider()

            // 任务列表
            if downloadService.tasks.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 48))
                        .foregroundStyle(.quaternary)
                    Text("暂无下载任务")
                        .foregroundStyle(.secondary)
                    Text("在搜索或排行榜中右键歌曲选择下载")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List {
                    ForEach(downloadService.tasks) { task in
                        DownloadTaskRow(task: task)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("下载")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackgroundVisibility(.visible, for: .navigationBar)
        .toolbarBackgroundVisibility(.visible, for: .tabBar)
        #endif
    }
}

// MARK: - 下载任务行

struct DownloadTaskRow: View {
    @Bindable var task: DownloadTask
    @Environment(DownloadService.self) private var downloadService

    var body: some View {
        HStack(spacing: 12) {
            // 封面
            AlbumCover(platform: task.song.platform, size: 40, coverUrl: task.song.coverUrl)

            // 信息
            VStack(alignment: .leading, spacing: 3) {
                Text(task.song.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    PlatformTag(platform: task.song.platform, small: true)
                    Text(task.song.artist)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // 状态
            switch task.state {
            case .waiting:
                Text("等待中")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .downloading:
                HStack(spacing: 8) {
                    ProgressView(value: task.progress)
                        .frame(width: 80)
                    Text("\(Int(task.progress * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            case .completed:
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("已完成")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            case .failed:
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(.red)
                    Button("重试") {
                        downloadService.retryFailed(task)
                    }
                    .font(.caption)
                    .buttonStyle(.plain)
                    .foregroundStyle(.blue)
                }
            }

            // 删除
            Button {
                downloadService.removeTask(task)
            } label: {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}
