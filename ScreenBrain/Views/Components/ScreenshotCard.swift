import SwiftUI

// MARK: - ScreenshotCard

struct ScreenshotCard: View {

    let screenshot: Screenshot

    @State private var isHovered: Bool = false

    private static let dateFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Thumbnail
            ZStack(alignment: .topTrailing) {
                thumbnailImage
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .frame(height: 130)
                    .clipped()

                if !screenshot.isAnalyzed {
                    analysisSpinner
                        .padding(8)
                }
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Circle()
                        .fill(screenshot.categoryEnum.color)
                        .frame(width: 7, height: 7)

                    Text(screenshot.categoryEnum.rawValue)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(PlatformColor.secondaryLabel)

                    Spacer()

                    Text(Self.dateFormatter.localizedString(for: screenshot.capturedAt, relativeTo: Date()))
                        .font(.system(size: 9))
                        .foregroundStyle(PlatformColor.tertiaryLabel)
                }

                if !screenshot.aiDescription.isEmpty {
                    Text(screenshot.aiDescription)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(PlatformColor.label.opacity(0.85))
                        .lineLimit(2)
                        .lineSpacing(1)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .background(PlatformColor.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .shadow(
            color: .black.opacity(isHovered ? 0.18 : 0.06),
            radius: isHovered ? 12 : 4,
            x: 0,
            y: isHovered ? 4 : 2
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
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
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [PlatformColor.secondaryFill, PlatformColor.tertiaryFill],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    Image(systemName: "photo")
                        .font(.system(size: 24, weight: .ultraLight))
                        .foregroundStyle(PlatformColor.quaternaryLabel)
                )
        }
    }

    // MARK: - Analysis Spinner

    private var analysisSpinner: some View {
        ProgressView()
            .scaleEffect(0.5)
            .tint(.white)
            .padding(4)
            .background(.ultraThinMaterial, in: Circle())
    }
}
