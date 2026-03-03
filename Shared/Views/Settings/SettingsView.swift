import SwiftUI

// MARK: - 设置页

struct SettingsView: View {
    @Environment(SettingsViewModel.self) private var settingsVM
    @Environment(MusicSourceEngine.self) private var engine
    @Environment(DownloadService.self) private var downloadService

    var body: some View {
        @Bindable var vm = settingsVM
        List {
            // 播放设置
            Section {
                Picker("默认音质", selection: $vm.selectedQuality) {
                    ForEach(MusicQuality.allCases) { q in
                        Label(q.displayName, systemImage: q.icon).tag(q)
                    }
                }

                Picker("播放模式", selection: $vm.defaultPlayMode) {
                    ForEach(PlayMode.allCases, id: \.self) { mode in
                        Label(mode.rawValue, systemImage: mode.icon).tag(mode)
                    }
                }
            } header: {
                Label("播放", systemImage: "play.circle")
            }

            // 下载设置
            Section {
                HStack {
                    Text("下载路径")
                    Spacer()
                    Text(downloadService.downloadPath)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
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
                    #endif
                }
            } header: {
                Label("下载", systemImage: "arrow.down.circle")
            }

            // 添加音源
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Label("输入订阅地址添加音源", systemImage: "link")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        TextField("订阅地址 (URL)", text: $vm.subscriptionUrl)
                            .textFieldStyle(.plain)
                            .padding(8)
                            .background(Color(.secondarySystemFill))
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        Button {
                            Task { await settingsVM.addSource(engine: engine) }
                        } label: {
                            if settingsVM.isAddingSource {
                                ProgressView().controlSize(.small)
                            } else {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                            }
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.purple)
                        .disabled(settingsVM.subscriptionUrl.isEmpty || settingsVM.isAddingSource)
                    }

                    if let err = settingsVM.addSourceError {
                        Label(err, systemImage: "xmark.circle")
                            .font(.caption).foregroundStyle(.red)
                    }
                    if settingsVM.addSourceSuccess {
                        Label("添加成功", systemImage: "checkmark.circle")
                            .font(.caption).foregroundStyle(.green)
                    }
                }
            } header: {
                Label("添加音源", systemImage: "plus.circle.fill")
            }

            // 已有音源
            Section {
                if engine.sources.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "tray").foregroundStyle(.tertiary)
                        Text("暂无音源").foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(engine.sources) { src in
                        HStack(spacing: 12) {
                            Circle()
                                .fill(src.isActive ? Color.green : .gray)
                                .frame(width: 8, height: 8)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(src.name).font(.body.weight(.medium))
                                Text("v\(src.version) · \(src.author)")
                                    .font(.caption).foregroundStyle(.secondary)
                            }

                            Spacer()

                            if src.subscriptionUrl != nil {
                                Button { Task { await settingsVM.updateSource(src, engine: engine) } } label: {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.caption).foregroundStyle(.blue)
                                }
                                .buttonStyle(.plain)
                            }

                            Button { settingsVM.removeSource(src, engine: engine) } label: {
                                Image(systemName: "trash")
                                    .font(.caption).foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            } header: {
                Label("已添加 (\(engine.sources.count))", systemImage: "square.stack")
            }

            // 快捷键
            #if os(macOS)
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    shortcutRow("⌘ Space", "播放 / 暂停")
                    shortcutRow("⌘ →", "下一首")
                    shortcutRow("⌘ ←", "上一首")
                    shortcutRow("⌘ ↑", "音量增大")
                    shortcutRow("⌘ ↓", "音量减小")
                    shortcutRow("⌘ L", "显示/隐藏歌词")
                    shortcutRow("⌘ F", "搜索")
                }
            } header: {
                Label("快捷键", systemImage: "keyboard")
            }
            #endif

            // 关于
            Section {
                LabeledContent("版本", value: "1.0.0")
                LabeledContent("引擎状态", value: engine.isLoaded ? "✅ 已就绪" : "⚠️ 未加载")
                LabeledContent("灵感来源", value: "洛雪音乐助手")
            } header: {
                Label("关于", systemImage: "info.circle")
            }
        }
        .navigationTitle("设置")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackgroundVisibility(.visible, for: .navigationBar)
        .toolbarBackgroundVisibility(.visible, for: .tabBar)
        #endif
    }

    #if os(macOS)
    private func shortcutRow(_ key: String, _ desc: String) -> some View {
        HStack {
            Text(key)
                .font(.system(.caption, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            Text(desc)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    #endif
}
