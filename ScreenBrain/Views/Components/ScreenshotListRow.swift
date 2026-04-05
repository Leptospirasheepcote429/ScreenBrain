import SwiftUI

// MARK: - ScreenshotListRow

struct ScreenshotListRow: View {

    let screenshot: Screenshot

    @State private var isHovered: Bool = false

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        HStack(spacing: 0) {
            // Thumbnail
            thumbnailImage
                .frame(width: 48, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                .shadow(color: .black.opacity(0.08), radius: 2, x: 0, y: 1)
                .padding(.trailing, 12)

            // Description
            VStack(alignment: .leading, spacing: 2) {
                Text(screenshot.aiDescription.isEmpty ? "Analyzing..." : screenshot.aiDescription)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(screenshot.aiDescription.isEmpty ? PlatformColor.tertiaryLabel : PlatformColor.label)
                    .lineLimit(1)

                if !screenshot.tags.isEmpty {
                    Text(screenshot.tags.prefix(3).joined(separator: " / "))
                        .font(.system(size: 10))
                        .foregroundStyle(PlatformColor.tertiaryLabel)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Category
            HStack(spacing: 5) {
                Circle()
                    .fill(screenshot.categoryEnum.color)
                    .frame(width: 7, height: 7)
                Text(screenshot.categoryEnum.rawValue)
                    .font(.system(size: 11))
                    .foregroundStyle(PlatformColor.secondaryLabel)
            }
            .frame(width: 110, alignment: .leading)

            // Date
            Text(Self.dateFormatter.string(from: screenshot.capturedAt))
                .font(.system(size: 11))
                .foregroundStyle(PlatformColor.tertiaryLabel)
                .frame(width: 130, alignment: .leading)

            // Status
            Group {
                if screenshot.isAnalyzed {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green.opacity(0.7))
                        .font(.system(size: 11))
                } else {
                    ProgressView()
                        .scaleEffect(0.45)
                }
            }
            .frame(width: 50)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isHovered ? PlatformColor.secondaryBackground : .clear)
        )
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .overlay(alignment: .bottom) {
            Divider()
                .padding(.leading, 76)
        }
    }

    // MARK: - Thumbnail

    @ViewBuilder
    private var thumbnailImage: some View {
        if let thumbData = screenshot.thumbnailData,
           let img = PlatformImage(data: thumbData) {
            Image(platformImage: img)
                .resizable()
                .scaledToFill()
        } else if let img = PlatformImage(data: screenshot.imageData) {
            Image(platformImage: img)
                .resizable()
                .scaledToFill()
        } else {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(PlatformColor.tertiaryFill)
                .overlay(
                    Image(systemName: "photo")
                        .font(.system(size: 10, weight: .ultraLight))
                        .foregroundStyle(PlatformColor.quaternaryLabel)
                )
        }
    }
}
