import Foundation
import SwiftData

@Model
final class Screenshot {
    var id: UUID
    @Attribute(.externalStorage) var imageData: Data
    @Attribute(.externalStorage) var thumbnailData: Data?
    var ocrText: String
    var aiDescription: String
    var category: String  // Category raw value stored as String for SwiftData
    var tags: [String]
    var sourceApp: String?
    var capturedAt: Date
    var analyzedAt: Date?
    var isAnalyzed: Bool

    var searchableText: String {
        [ocrText, aiDescription, tags.joined(separator: " "), sourceApp ?? ""]
            .joined(separator: " ")
            .lowercased()
    }

    var categoryEnum: Category {
        Category(rawValue: category) ?? .other
    }

    init(imageData: Data, capturedAt: Date) {
        self.id = UUID()
        self.imageData = imageData
        self.thumbnailData = nil
        self.ocrText = ""
        self.aiDescription = ""
        self.category = Category.other.rawValue
        self.tags = []
        self.sourceApp = nil
        self.capturedAt = capturedAt
        self.analyzedAt = nil
        self.isAnalyzed = false
    }
}
