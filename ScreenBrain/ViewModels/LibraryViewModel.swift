import Foundation
import Photos
import SwiftData
import SwiftUI

// MARK: - SortOrder

enum SortOrder: String, CaseIterable, Identifiable {
    case newest  = "Newest First"
    case oldest  = "Oldest First"
    case category = "By Category"

    var id: String { rawValue }
}

// MARK: - LibraryViewModel

@Observable
final class LibraryViewModel {

    // MARK: - State

    var screenshots: [Screenshot] = []
    var selectedCategory: Category? = nil
    var sortOrder: SortOrder = .newest
    var isImporting: Bool = false
    var importProgress: Double = 0
    var showError: Bool = false
    var errorMessage: String = ""

    // MARK: - Load

    func loadScreenshots(context: ModelContext) {
        let descriptor = FetchDescriptor<Screenshot>(
            sortBy: [SortDescriptor(\.capturedAt, order: .reverse)]
        )
        let all = (try? context.fetch(descriptor)) ?? []

        var filtered: [Screenshot]
        if let category = selectedCategory {
            filtered = all.filter { $0.categoryEnum == category }
        } else {
            filtered = all
        }

        switch sortOrder {
        case .newest:
            filtered.sort { $0.capturedAt > $1.capturedAt }
        case .oldest:
            filtered.sort { $0.capturedAt < $1.capturedAt }
        case .category:
            filtered.sort {
                if $0.category == $1.category {
                    return $0.capturedAt > $1.capturedAt
                }
                return $0.category < $1.category
            }
        }

        screenshots = filtered
    }

    // MARK: - Import Preview (count before importing)

    var pendingImportCount: Int = 0
    var showImportConfirmation: Bool = false
    var importLimit: Int? = nil  // nil = import all
    private var cachedNewAssets: [PHAsset] = []

    /// Checks how many new screenshots are available to import and shows a confirmation dialog.
    func previewImport(
        photosService: PhotosService,
        context: ModelContext
    ) async {
        let assets = await photosService.fetchScreenshots(limit: nil)
        guard !assets.isEmpty else {
            await MainActor.run {
                pendingImportCount = 0
                errorMessage = "No screenshots found in your Photos library."
                showError = true
            }
            return
        }

        let existingDescriptor = FetchDescriptor<Screenshot>()
        let existing = (try? context.fetch(existingDescriptor)) ?? []
        let existingDates = Set(existing.map { $0.capturedAt })

        let newAssets = assets.filter { asset in
            guard let date = asset.creationDate else { return false }
            return !existingDates.contains(date)
        }

        await MainActor.run {
            pendingImportCount = newAssets.count
            cachedNewAssets = newAssets
            importLimit = nil

            if newAssets.isEmpty {
                errorMessage = "All screenshots are already imported."
                showError = true
            } else {
                showImportConfirmation = true
            }
        }
    }

    // MARK: - Import from Photos

    /// Runs the actual import. Call after user confirms via the dialog.
    func importFromPhotos(
        photosService: PhotosService,
        aiService: AIService,
        context: ModelContext,
        limit: Int? = nil
    ) async {
        guard !isImporting else { return }

        await MainActor.run {
            isImporting = true
            importProgress = 0
            showImportConfirmation = false
        }

        defer {
            Task { @MainActor in
                isImporting = false
                importProgress = 1.0
                cachedNewAssets = []
            }
        }

        // Use cached assets if available, otherwise fetch fresh
        let newAssets: [PHAsset]
        if !cachedNewAssets.isEmpty {
            newAssets = cachedNewAssets
        } else {
            let assets = await photosService.fetchScreenshots(limit: nil)
            let existingDescriptor = FetchDescriptor<Screenshot>()
            let existing = (try? context.fetch(existingDescriptor)) ?? []
            let existingDates = Set(existing.map { $0.capturedAt })
            newAssets = assets.filter { asset in
                guard let date = asset.creationDate else { return false }
                return !existingDates.contains(date)
            }
        }

        guard !newAssets.isEmpty else {
            await MainActor.run { isImporting = false }
            return
        }

        // Apply limit if set
        let assetsToImport: ArraySlice<PHAsset>
        if let limit, limit > 0, limit < newAssets.count {
            assetsToImport = newAssets.prefix(limit)
        } else {
            assetsToImport = newAssets[...]
        }

        let total = Double(assetsToImport.count)

        for (index, asset) in assetsToImport.enumerated() {
            // Load full image data
            guard let imageData = try? await photosService.loadImageData(for: asset) else {
                await MainActor.run {
                    importProgress = Double(index + 1) / total
                }
                continue
            }

            let capturedAt = asset.creationDate ?? Date()

            // Create model
            let screenshot = Screenshot(imageData: imageData, capturedAt: capturedAt)

            // Load thumbnail
            if let thumbData = try? await photosService.loadThumbnail(
                for: asset,
                size: LayoutConstants.thumbnailSize
            ) {
                screenshot.thumbnailData = thumbData
            }

            // Insert into context early so UI can show it
            await MainActor.run {
                context.insert(screenshot)
                try? context.save()
                loadScreenshots(context: context)
                importProgress = Double(index + 1) / total * 0.5
            }

            // Run AI analysis
            if let result = try? await aiService.analyzeScreenshot(imageData: imageData) {
                await MainActor.run {
                    screenshot.ocrText = result.ocrText
                    screenshot.aiDescription = result.description
                    screenshot.category = result.category
                    screenshot.tags = result.tags
                    screenshot.sourceApp = result.sourceApp
                    screenshot.analyzedAt = Date()
                    screenshot.isAnalyzed = true
                    try? context.save()
                    loadScreenshots(context: context)
                }
            }

            await MainActor.run {
                importProgress = 0.5 + Double(index + 1) / total * 0.5
            }
        }

        await MainActor.run {
            importProgress = 1.0
            loadScreenshots(context: context)
        }
    }

    // MARK: - Delete

    func deleteScreenshot(_ screenshot: Screenshot, context: ModelContext) {
        context.delete(screenshot)
        try? context.save()
        loadScreenshots(context: context)
    }

    // MARK: - Filter

    func filterByCategory(_ category: Category?, context: ModelContext) {
        selectedCategory = category
        loadScreenshots(context: context)
    }
}