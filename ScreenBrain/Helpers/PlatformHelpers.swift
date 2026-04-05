import SwiftUI

#if os(iOS)
import UIKit
typealias PlatformImage = UIImage
#elseif os(macOS)
import AppKit
typealias PlatformImage = NSImage
#endif

// MARK: - Cross-Platform Image

extension Image {
    init?(platformData: Data) {
        guard let img = PlatformImage(data: platformData) else { return nil }
        #if os(iOS)
        self.init(uiImage: img)
        #elseif os(macOS)
        self.init(nsImage: img)
        #endif
    }

    init(platformImage: PlatformImage) {
        #if os(iOS)
        self.init(uiImage: platformImage)
        #elseif os(macOS)
        self.init(nsImage: platformImage)
        #endif
    }
}

extension PlatformImage {
    func jpegRepresentation(quality: CGFloat = 0.8) -> Data? {
        #if os(iOS)
        return jpegData(compressionQuality: quality)
        #elseif os(macOS)
        guard let tiffData = tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiffData) else { return nil }
        return rep.representation(using: .jpeg, properties: [.compressionFactor: quality])
        #endif
    }
}

// MARK: - Cross-Platform Colors

enum PlatformColor {
    static var label: Color {
        #if os(iOS)
        Color(.label)
        #elseif os(macOS)
        Color(.labelColor)
        #endif
    }

    static var secondaryLabel: Color {
        #if os(iOS)
        Color(.secondaryLabel)
        #elseif os(macOS)
        Color(.secondaryLabelColor)
        #endif
    }

    static var tertiaryLabel: Color {
        #if os(iOS)
        Color(.tertiaryLabel)
        #elseif os(macOS)
        Color(.tertiaryLabelColor)
        #endif
    }

    static var quaternaryLabel: Color {
        #if os(iOS)
        Color(.quaternaryLabel)
        #elseif os(macOS)
        Color(.quaternaryLabelColor)
        #endif
    }

    static var background: Color {
        #if os(iOS)
        Color(.systemBackground)
        #elseif os(macOS)
        Color(.windowBackgroundColor)
        #endif
    }

    static var secondaryBackground: Color {
        #if os(iOS)
        Color(.secondarySystemBackground)
        #elseif os(macOS)
        Color(.controlBackgroundColor)
        #endif
    }

    static var tertiaryFill: Color {
        #if os(iOS)
        Color(.tertiarySystemFill)
        #elseif os(macOS)
        Color(.underPageBackgroundColor)
        #endif
    }

    static var secondaryFill: Color {
        #if os(iOS)
        Color(.secondarySystemFill)
        #elseif os(macOS)
        Color(.controlColor)
        #endif
    }
}

// MARK: - Haptic Feedback (no-op on macOS)

enum HapticFeedback {
    static func light() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    static func medium() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
    }

    static func success() {
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }

    static func warning() {
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        #endif
    }
}
