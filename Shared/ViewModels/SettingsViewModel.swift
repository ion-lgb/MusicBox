import Foundation

/// 设置 ViewModel
@MainActor @Observable
final class SettingsViewModel {
    var subscriptionUrl: String = ""
    var isAddingSource = false
    var addSourceError: String?
    var addSourceSuccess = false

    // 音质
    var selectedQuality: MusicQuality {
        didSet { UserDefaults.standard.set(selectedQuality.rawValue, forKey: "selectedQuality") }
    }

    // 播放模式
    var defaultPlayMode: PlayMode {
        didSet { UserDefaults.standard.set(defaultPlayMode.rawValue, forKey: "defaultPlayMode") }
    }

    init() {
        let qRaw = UserDefaults.standard.string(forKey: "selectedQuality") ?? MusicQuality.high.rawValue
        selectedQuality = MusicQuality(rawValue: qRaw) ?? .high

        let pRaw = UserDefaults.standard.string(forKey: "defaultPlayMode") ?? PlayMode.loop.rawValue
        defaultPlayMode = PlayMode(rawValue: pRaw) ?? .loop
    }

    func addSource(engine: MusicSourceEngine) async {
        let url = subscriptionUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !url.isEmpty else {
            addSourceError = "请输入订阅地址"
            return
        }

        isAddingSource = true
        addSourceError = nil
        addSourceSuccess = false

        do {
            try await engine.addSourceFromURL(url)
            isAddingSource = false
            addSourceSuccess = true
            subscriptionUrl = ""
        } catch {
            isAddingSource = false
            addSourceError = error.localizedDescription
        }
    }

    func updateSource(_ source: MusicSourceConfig, engine: MusicSourceEngine) async {
        do {
            try await engine.updateSource(source)
        } catch {
            addSourceError = error.localizedDescription
        }
    }

    func removeSource(_ source: MusicSourceConfig, engine: MusicSourceEngine) {
        try? engine.removeSource(source)
    }
}
