import Foundation
import SwiftData

// MARK: - SearchViewModel

@Observable
final class SearchViewModel {

    // MARK: - State

    var query: String = ""
    var results: [Screenshot] = []
    var isSearching: Bool = false
    var recentSearches: [String] = []
    var suggestedCategories: [Category] = Category.allCases

    // MARK: - Constants

    private enum Keys {
        static let recentSearches = "recent_searches"
        static let maxRecentSearches = 10
    }

    // MARK: - Init

    init() {
        loadRecentSearches()
    }

    // MARK: - Search

    func performSearch(context: ModelContext, searchService: SearchService) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            results = []
            isSearching = false
            return
        }

        isSearching = true
        let found = searchService.search(query: trimmed, in: context)
        results = found
        isSearching = false
    }

    // MARK: - Clear

    func clearSearch() {
        query = ""
        results = []
        isSearching = false
    }

    // MARK: - Recent Searches

    func addToRecentSearches(_ term: String) {
        let clean = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }

        var updated = recentSearches.filter { $0 != clean }
        updated.insert(clean, at: 0)
        if updated.count > Keys.maxRecentSearches {
            updated = Array(updated.prefix(Keys.maxRecentSearches))
        }
        recentSearches = updated
        saveRecentSearches()
    }

    func removeRecentSearch(_ term: String) {
        recentSearches.removeAll { $0 == term }
        saveRecentSearches()
    }

    func clearRecentSearches() {
        recentSearches = []
        saveRecentSearches()
    }

    // MARK: - Persistence

    private func loadRecentSearches() {
        recentSearches = UserDefaults.standard.stringArray(forKey: Keys.recentSearches) ?? []
    }

    private func saveRecentSearches() {
        UserDefaults.standard.set(recentSearches, forKey: Keys.recentSearches)
    }
}
