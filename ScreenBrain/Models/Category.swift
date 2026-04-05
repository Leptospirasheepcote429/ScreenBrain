import SwiftUI

enum Category: String, CaseIterable, Identifiable, Codable {
    case code = "Code"
    case error = "Error"
    case design = "Design"
    case social = "Social Media"
    case chat = "Conversation"
    case article = "Article"
    case receipt = "Receipt"
    case photo = "Photo"
    case other = "Other"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .code:    return "chevron.left.forwardslash.chevron.right"
        case .error:   return "exclamationmark.triangle.fill"
        case .design:  return "paintbrush.fill"
        case .social:  return "heart.circle.fill"
        case .chat:    return "bubble.left.and.bubble.right.fill"
        case .article: return "doc.text.fill"
        case .receipt: return "receipt"
        case .photo:   return "photo.fill"
        case .other:   return "square.grid.2x2.fill"
        }
    }

    var color: Color {
        switch self {
        case .code:    return .blue
        case .error:   return .red
        case .design:  return .purple
        case .social:  return .pink
        case .chat:    return .green
        case .article: return .orange
        case .receipt: return .yellow
        case .photo:   return .cyan
        case .other:   return .gray
        }
    }
}
