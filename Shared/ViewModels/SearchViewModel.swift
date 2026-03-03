import Foundation

/// 搜索 ViewModel
@MainActor @Observable
final class SearchViewModel {
    var keyword: String = ""
    var results: [Song] = []
    var isSearching = false
    var errorMessage: String?
    var selectedPlatform: MusicPlatform? = nil  // nil = 全部

    // 分页
    var currentPage: Int = 1
    var hasMore = false
    private let pageSize = 30

    // 搜索历史
    var searchHistory: [String] = [] {
        didSet {
            UserDefaults.standard.set(searchHistory, forKey: "searchHistory")
        }
    }

    init() {
        searchHistory = UserDefaults.standard.stringArray(forKey: "searchHistory") ?? []
    }

    func search(engine: MusicSourceEngine) async {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isSearching = true
        errorMessage = nil
        currentPage = 1

        do {
            results = try await engine.search(keyword: trimmed, platform: selectedPlatform, page: currentPage)
            hasMore = results.count >= pageSize
            addToHistory(trimmed)
        } catch {
            errorMessage = error.localizedDescription
            results = []
        }

        isSearching = false
    }

    func loadNextPage(engine: MusicSourceEngine) async {
        guard hasMore, !isSearching else { return }
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isSearching = true
        currentPage += 1

        do {
            let newResults = try await engine.search(keyword: trimmed, platform: selectedPlatform, page: currentPage)
            results.append(contentsOf: newResults)
            hasMore = newResults.count >= pageSize
        } catch {
            currentPage -= 1
        }

        isSearching = false
    }

    func clear() {
        keyword = ""
        results = []
        errorMessage = nil
        currentPage = 1
        hasMore = false
    }

    func clearHistory() {
        searchHistory = []
    }

    private func addToHistory(_ keyword: String) {
        searchHistory.removeAll { $0 == keyword }
        searchHistory.insert(keyword, at: 0)
        if searchHistory.count > 20 { searchHistory = Array(searchHistory.prefix(20)) }
    }
}
