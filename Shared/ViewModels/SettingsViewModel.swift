import Foundation

/// 设置 ViewModel
@MainActor @Observable
final class SettingsViewModel {
    var subscriptionUrl: String = ""
    var isAddingSource = false
    var addSourceError: String?
    var addSourceSuccess = false

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
