import Foundation

/// 搜索 ViewModel
@MainActor @Observable
final class SearchViewModel {
    var keyword: String = ""
    var results: [Song] = []
    var isSearching = false
    var errorMessage: String?
    var selectedPlatform: MusicPlatform? = nil  // nil = 全部

    func search(engine: MusicSourceEngine) async {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isSearching = true
        errorMessage = nil

        do {
            results = try await engine.search(keyword: trimmed, platform: selectedPlatform)
        } catch {
            errorMessage = error.localizedDescription
            results = []
        }

        isSearching = false
    }

    func clear() {
        keyword = ""
        results = []
        errorMessage = nil
    }
}
