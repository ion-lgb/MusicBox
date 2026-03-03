import SwiftUI

/// 设置页
struct SettingsView: View {
    @Environment(SettingsViewModel.self) private var settingsVM
    @Environment(MusicSourceEngine.self) private var engine

    var body: some View {
        @Bindable var vm = settingsVM
        Form {
            // 音源管理
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("输入音源订阅地址，自动下载并加载音源脚本")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack {
                        TextField("订阅地址 (URL)", text: $vm.subscriptionUrl)
                            .textFieldStyle(.roundedBorder)

                        Button {
                            Task { await settingsVM.addSource(engine: engine) }
                        } label: {
                            if settingsVM.isAddingSource {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Text("添加")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(settingsVM.subscriptionUrl.isEmpty || settingsVM.isAddingSource)
                    }

                    if let error = settingsVM.addSourceError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    if settingsVM.addSourceSuccess {
                        Label("音源添加成功", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
            } header: {
                Text("添加音源")
            }

            // 已有音源列表
            Section {
                if engine.sources.isEmpty {
                    Text("还没有添加任何音源")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                } else {
                    ForEach(engine.sources) { source in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(source.name)
                                        .font(.body.weight(.medium))
                                    Text("v\(source.version) · \(source.author)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                // 更新按钮
                                if source.subscriptionUrl != nil {
                                    Button {
                                        Task {
                                            await settingsVM.updateSource(source, engine: engine)
                                        }
                                    } label: {
                                        Image(systemName: "arrow.clockwise")
                                            .font(.caption)
                                    }
                                    .buttonStyle(.borderless)
                                }

                                // 删除按钮
                                Button(role: .destructive) {
                                    settingsVM.removeSource(source, engine: engine)
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.caption)
                                }
                                .buttonStyle(.borderless)
                            }

                            if let url = source.subscriptionUrl {
                                Text(url)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            } header: {
                Text("已添加的音源 (\(engine.sources.count))")
            }

            // 关于
            Section {
                HStack {
                    Text("版本")
                    Spacer()
                    Text("1.0.0")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("音源引擎")
                    Spacer()
                    Text(engine.isLoaded ? "已就绪" : "未加载")
                        .foregroundStyle(engine.isLoaded ? .green : .orange)
                }
            } header: {
                Text("关于")
            }
        }
        .navigationTitle("设置")
        .formStyle(.grouped)
    }
}
