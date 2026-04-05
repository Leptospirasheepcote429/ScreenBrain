import SwiftUI

// MARK: - DetailView

struct DetailView: View {

    let screenshot: Screenshot
    var onDelete: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var isOCRExpanded: Bool = false
    @State private var showDeleteAlert: Bool = false

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .long
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        HStack(spacing: 0) {
            // Left: Image
            imageSection
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.03))

            Divider()

            // Right: Info panel
            ScrollView {
                analysisCard
                    .padding(24)
            }
            .frame(width: 320)
            .background(PlatformColor.background)
        }
        .navigationTitle("")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(role: .destructive) {
                    showDeleteAlert = true
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.red.opacity(0.8))
                }
            }
        }
        .alert("Delete Screenshot?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                onDelete?()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove the screenshot from ScreenBrain. The original photo will remain in your Photos library.")
        }
    }

    // MARK: - Image Section

    private var imageSection: some View {
        GeometryReader { geo in
            let fullImage: PlatformImage? = {
                if let data = screenshot.thumbnailData, let img = PlatformImage(data: data) { return img }
                return PlatformImage(data: screenshot.imageData)
            }()

            ZStack {
                if let img = fullImage {
                    Image(platformImage: img)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    scale = max(1.0, min(lastScale * value, 5.0))
                                }
                                .onEnded { _ in
                                    lastScale = scale
                                    if scale < 1.05 {
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                            scale = 1.0
                                            offset = .zero
                                        }
                                        lastScale = 1.0
                                        lastOffset = .zero
                                    }
                                }
                                .simultaneously(with:
                                    DragGesture()
                                        .onChanged { value in
                                            if scale > 1.0 {
                                                offset = CGSize(
                                                    width: lastOffset.width + value.translation.width,
                                                    height: lastOffset.height + value.translation.height
                                                )
                                            }
                                        }
                                        .onEnded { _ in
                                            lastOffset = offset
                                        }
                                )
                        )
                        .onTapGesture(count: 2) {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                if scale > 1.0 {
                                    scale = 1.0
                                    offset = .zero
                                    lastScale = 1.0
                                    lastOffset = .zero
                                } else {
                                    scale = 2.5
                                    lastScale = 2.5
                                }
                            }
                        }
                        .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 8)
                        .padding(24)
                } else {
                    ProgressView()
                        .tint(PlatformColor.tertiaryLabel)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    // MARK: - Analysis Card

    private var analysisCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Category
            categoryBadge
                .padding(.bottom, 16)

            // Source app
            if let source = screenshot.sourceApp, !source.isEmpty {
                HStack(spacing: 5) {
                    Image(systemName: "app.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(PlatformColor.tertiaryLabel)
                    Text(source)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(PlatformColor.secondaryLabel)
                }
                .padding(.bottom, 14)
            }

            // Description
            if !screenshot.aiDescription.isEmpty {
                Text(screenshot.aiDescription)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(PlatformColor.label)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(2)
                    .padding(.bottom, 18)
            } else if !screenshot.isAnalyzed {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.6)
                        .tint(PlatformColor.tertiaryLabel)
                    Text("Analyzing...")
                        .font(.system(size: 13))
                        .foregroundStyle(PlatformColor.tertiaryLabel)
                }
                .padding(.bottom, 18)
            }

            // Tags
            if !screenshot.tags.isEmpty {
                tagsSection
                    .padding(.bottom, 18)
            }

            Divider()
                .opacity(0.5)
                .padding(.bottom, 14)

            // Date
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.system(size: 11))
                    .foregroundStyle(PlatformColor.tertiaryLabel)
                Text(Self.dateFormatter.string(from: screenshot.capturedAt))
                    .font(.system(size: 12))
                    .foregroundStyle(PlatformColor.secondaryLabel)
            }
            .padding(.bottom, 18)

            // OCR
            if !screenshot.ocrText.isEmpty {
                ocrSection
            }
        }
    }

    // MARK: - Category Badge

    private var categoryBadge: some View {
        let cat = screenshot.categoryEnum
        return HStack(spacing: 5) {
            Image(systemName: cat.icon)
                .font(.system(size: 11, weight: .semibold))
            Text(cat.rawValue)
                .font(.system(size: 12, weight: .semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(cat.color.opacity(0.12))
        )
        .foregroundStyle(cat.color)
    }

    // MARK: - Tags

    private var tagsSection: some View {
        FlowLayoutDetail(spacing: 6) {
            ForEach(screenshot.tags, id: \.self) { tag in
                Text("#\(tag)")
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(PlatformColor.tertiaryFill)
                    )
                    .foregroundStyle(PlatformColor.secondaryLabel)
            }
        }
    }

    // MARK: - OCR Section

    private var ocrSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    isOCRExpanded.toggle()
                }
            } label: {
                HStack {
                    Text("Extracted Text")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(PlatformColor.label)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(PlatformColor.tertiaryLabel)
                        .rotationEffect(.degrees(isOCRExpanded ? 90 : 0))
                }
            }
            .buttonStyle(.plain)

            if isOCRExpanded {
                Text(screenshot.ocrText)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(PlatformColor.secondaryLabel)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(PlatformColor.tertiaryFill)
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// MARK: - FlowLayout for Detail

private struct FlowLayoutDetail: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 280
        var height: CGFloat = 0
        var currentRowWidth: CGFloat = 0
        var currentRowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentRowWidth + size.width > width && currentRowWidth > 0 {
                height += currentRowHeight + spacing
                currentRowWidth = 0
                currentRowHeight = 0
            }
            currentRowWidth += size.width + spacing
            currentRowHeight = max(currentRowHeight, size.height)
        }
        height += currentRowHeight
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var currentRowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                y += currentRowHeight + spacing
                x = bounds.minX
                currentRowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            currentRowHeight = max(currentRowHeight, size.height)
        }
    }
}
