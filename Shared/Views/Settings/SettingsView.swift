import SwiftUI

/// 设置页
struct SettingsView: View {
    @Environment(SettingsViewModel.self) private var settingsVM
    @Environment(MusicSourceEngine.self) private var engine

    var body: some View {
        @Bindable var vm = settingsVM
        ScrollView {
            VStack(spacing: DesignTokens.spacingLG) {

                // 添加音源
                settingsSection(title: "添加音源", icon: "plus.circle.fill", iconColor: .green) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("输入音源订阅地址，自动下载并加载音源脚本")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 10) {
                            TextField("订阅地址 (URL)", text: $vm.subscriptionUrl)
                                .textFieldStyle(.plain)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(Color(.secondarySystemFill))
                                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusSM))

                            Button {
                                Task { await settingsVM.addSource(engine: engine) }
                            } label: {
                                Group {
                                    if settingsVM.isAddingSource {
                                        ProgressView()
                                            .controlSize(.small)
                                    } else {
                                        Image(systemName: "arrow.down.circle.fill")
                                            .font(.title2)
                                    }
                                }
                                .frame(width: 38, height: 38)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.tint)
                            .disabled(settingsVM.subscriptionUrl.isEmpty || settingsVM.isAddingSource)
                        }

                        if let error = settingsVM.addSourceError {
                            Label(error, systemImage: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }

                        if settingsVM.addSourceSuccess {
                            Label("音源添加成功", systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    }
                }

                // 已有音源
                settingsSection(
                    title: "已添加的音源",
                    icon: "square.stack.fill",
                    iconColor: .purple,
                    badge: "\(engine.sources.count)"
                ) {
                    if engine.sources.isEmpty {
                        HStack {
                            Image(systemName: "tray")
                                .foregroundStyle(.tertiary)
                            Text("还没有添加任何音源")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 8)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(engine.sources) { source in
                                sourceRow(source)
                            }
                        }
                    }
                }

                // 关于
                settingsSection(title: "关于", icon: "info.circle.fill", iconColor: .blue) {
                    VStack(spacing: 0) {
                        infoRow(title: "版本", value: "1.0.0")
                        Divider().padding(.leading, 12)
                        infoRow(title: "音源引擎",
                               value: engine.isLoaded ? "已就绪" : "未加载",
                               valueColor: engine.isLoaded ? .green : .orange)
                        Divider().padding(.leading, 12)
                        infoRow(title: "灵感来源", value: "洛雪音乐助手")
                    }
                }
            }
            .padding(DesignTokens.spacingMD)
        }
        .navigationTitle("设置")
    }

    // MARK: - Section 容器

    private func settingsSection<Content: View>(
        title: String,
        icon: String,
        iconColor: Color,
        badge: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(iconColor)
                    .font(.callout)
                Text(title)
                    .font(.headline)
                if let badge = badge {
                    Text(badge)
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(iconColor.opacity(0.15))
                        .foregroundStyle(iconColor)
                        .clipShape(Capsule())
                }
                Spacer()
            }

            content()
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemFill))
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusMD))
        }
    }

    // MARK: - 音源行

    private func sourceRow(_ source: MusicSourceConfig) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(source.isActive ? Color.green : Color.gray)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(source.name)
                    .font(.callout.weight(.medium))
                HStack(spacing: 4) {
                    Text("v\(source.version)")
                    if !source.author.isEmpty {
                        Text("·")
                        Text(source.author)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if source.subscriptionUrl != nil {
                Button {
                    Task { await settingsVM.updateSource(source, engine: engine) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                        .padding(6)
                        .background(Circle().fill(Color(.secondarySystemFill)))
                }
                .buttonStyle(.plain)
            }

            Button(role: .destructive) {
                settingsVM.removeSource(source, engine: engine)
            } label: {
                Image(systemName: "trash")
                    .font(.caption)
                    .padding(6)
                    .background(Circle().fill(Color.red.opacity(0.1)))
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusSM))
    }

    // MARK: - 信息行

    private func infoRow(title: String, value: String, valueColor: Color = .secondary) -> some View {
        HStack {
            Text(title)
                .font(.callout)
            Spacer()
            Text(value)
                .font(.callout)
                .foregroundStyle(valueColor)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
    }
}
