import Foundation
import SwiftData

@Observable
final class SearchService {

    // MARK: - Full-Text Search

    /// Searches screenshots whose searchableText contains any of the whitespace-split
    /// words from `query`.  Uses an in-memory filter because SwiftData's #Predicate
    /// does not support complex string operations reliably.
    func search(query: String, in context: ModelContext) -> [Screenshot] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return recentScreenshots(limit: Int.max, in: context)
        }

        let words = trimmed
            .lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }

        let all = fetchAll(ascending: false, in: context)

        return all.filter { screenshot in
            let haystack = screenshot.searchableText
            return words.contains { haystack.contains($0) }
        }
    }

    // MARK: - Category Search

    func searchByCategory(_ category: Category, in context: ModelContext) -> [Screenshot] {
        let rawValue = category.rawValue
        let descriptor = FetchDescriptor<Screenshot>(
            predicate: #Predicate { $0.category == rawValue },
            sortBy: [SortDescriptor(\.capturedAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    // MARK: - Date Range Search

    func searchByDateRange(from startDate: Date, to endDate: Date, in context: ModelContext) -> [Screenshot] {
        let descriptor = FetchDescriptor<Screenshot>(
            predicate: #Predicate { $0.capturedAt >= startDate && $0.capturedAt <= endDate },
            sortBy: [SortDescriptor(\.capturedAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    // MARK: - Recent Screenshots

    func recentScreenshots(limit: Int, in context: ModelContext) -> [Screenshot] {
        var descriptor = FetchDescriptor<Screenshot>(
            sortBy: [SortDescriptor(\.capturedAt, order: .reverse)]
        )
        if limit != Int.max {
            descriptor.fetchLimit = limit
        }
        return (try? context.fetch(descriptor)) ?? []
    }

    // MARK: - Private Helpers

    private func fetchAll(ascending: Bool, in context: ModelContext) -> [Screenshot] {
        let descriptor = FetchDescriptor<Screenshot>(
            sortBy: [SortDescriptor(\Screenshot.capturedAt, order: ascending ? .forward : .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }
}
