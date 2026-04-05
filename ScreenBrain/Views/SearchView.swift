import SwiftUI
import SwiftData

// MARK: - SearchView

struct SearchView: View {

    @Environment(\.modelContext) private var modelContext
    @Bindable var viewModel: SearchViewModel
    var searchService: SearchService

    @FocusState private var isSearchFocused: Bool
    @State private var selectedScreenshot: Screenshot? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                Divider()
                    .opacity(0.5)

                ZStack {
                    if viewModel.query.isEmpty {
                        emptyQueryContent
                    } else if viewModel.isSearching {
                        VStack {
                            Spacer()
                            ProgressView()
                                .scaleEffect(1.0)
                                .tint(PlatformColor.tertiaryLabel)
                            Spacer()
                        }
                    } else if viewModel.results.isEmpty {
                        noResultsView
                    } else {
                        resultsList
                    }
                }
            }
            .navigationTitle("Search")
            .navigationDestination(item: $selectedScreenshot) { screenshot in
                DetailView(screenshot: screenshot, onDelete: {
                    selectedScreenshot = nil
                })
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(PlatformColor.tertiaryLabel)

            TextField("Search screenshots...", text: $viewModel.query)
                .focused($isSearchFocused)
                .autocorrectionDisabled()
                .font(.system(size: 13))
                .onSubmit {
                    if !viewModel.query.isEmpty {
                        viewModel.addToRecentSearches(viewModel.query)
                    }
                }
                .onChange(of: viewModel.query) { _, newValue in
                    if newValue.isEmpty {
                        viewModel.clearSearch()
                    } else {
                        viewModel.performSearch(context: modelContext, searchService: searchService)
                    }
                }

            if !viewModel.query.isEmpty {
                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        viewModel.clearSearch()
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(PlatformColor.tertiaryLabel)
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(PlatformColor.secondaryBackground)
        )
    }

    // MARK: - Empty Query Content

    private var emptyQueryContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                if !viewModel.recentSearches.isEmpty {
                    recentSearchesSection
                }
                categorySuggestionsSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
        }
    }

    // MARK: - Recent Searches

    private var recentSearchesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Searches")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(PlatformColor.secondaryLabel)
                    .textCase(.uppercase)
                    .tracking(0.5)

                Spacer()

                Button("Clear") {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        viewModel.clearRecentSearches()
                    }
                }
                .font(.system(size: 11))
                .foregroundStyle(PlatformColor.tertiaryLabel)
                .buttonStyle(.plain)
            }

            FlowLayout(spacing: 6) {
                ForEach(viewModel.recentSearches, id: \.self) { term in
                    Button {
                        viewModel.query = term
                        viewModel.performSearch(context: modelContext, searchService: searchService)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 9))
                            Text(term)
                                .font(.system(size: 12))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(PlatformColor.secondaryBackground)
                        )
                        .foregroundStyle(PlatformColor.secondaryLabel)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Category Suggestions

    private var categorySuggestionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Browse by Category")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(PlatformColor.secondaryLabel)
                .textCase(.uppercase)
                .tracking(0.5)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10)
                ],
                spacing: 10
            ) {
                ForEach(viewModel.suggestedCategories) { category in
                    CategoryTile(category: category) {
                        viewModel.query = category.rawValue
                        viewModel.performSearch(context: modelContext, searchService: searchService)
                    }
                }
            }
        }
    }

    // MARK: - Results List

    private var resultsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.results) { screenshot in
                    SearchResultRow(screenshot: screenshot)
                        .onTapGesture {
                            selectedScreenshot = screenshot
                        }
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: viewModel.results.map(\.id))
        }
    }

    // MARK: - No Results

    private var noResultsView: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40, weight: .ultraLight))
                .foregroundStyle(PlatformColor.tertiaryLabel)

            Text("No results for \"\(viewModel.query)\"")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(PlatformColor.secondaryLabel)

            Text("Try different keywords or browse by category")
                .font(.system(size: 12))
                .foregroundStyle(PlatformColor.tertiaryLabel)
            Spacer()
        }
    }
}

// MARK: - CategoryTile

private struct CategoryTile: View {
    let category: Category
    let action: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(category.color.opacity(isHovered ? 0.18 : 0.1))
                        .aspectRatio(1.3, contentMode: .fit)

                    Image(systemName: category.icon)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(category.color)
                }

                Text(category.rawValue)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(PlatformColor.secondaryLabel)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.03 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - SearchResultRow

private struct SearchResultRow: View {
    let screenshot: Screenshot

    @State private var isHovered: Bool = false

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        HStack(spacing: 12) {
            thumbnailView
                .frame(width: 56, height: 42)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .shadow(color: .black.opacity(0.06), radius: 2, x: 0, y: 1)

            VStack(alignment: .leading, spacing: 3) {
                Text(screenshot.aiDescription.isEmpty ? "Processing..." : screenshot.aiDescription)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(screenshot.aiDescription.isEmpty ? PlatformColor.tertiaryLabel : PlatformColor.label)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    HStack(spacing: 3) {
                        Circle()
                            .fill(screenshot.categoryEnum.color)
                            .frame(width: 6, height: 6)
                        Text(screenshot.categoryEnum.rawValue)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(screenshot.categoryEnum.color)
                    }

                    Text(Self.dateFormatter.string(from: screenshot.capturedAt))
                        .font(.system(size: 10))
                        .foregroundStyle(PlatformColor.tertiaryLabel)
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(PlatformColor.tertiaryLabel)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isHovered ? PlatformColor.secondaryBackground : .clear)
        )
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .overlay(alignment: .bottom) {
            Divider()
                .padding(.leading, 84)
                .opacity(0.4)
        }
    }

    @ViewBuilder
    private var thumbnailView: some View {
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
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(PlatformColor.tertiaryFill)
                .overlay(
                    Image(systemName: "photo")
                        .font(.system(size: 12, weight: .ultraLight))
                        .foregroundStyle(PlatformColor.quaternaryLabel)
                )
        }
    }
}

// MARK: - FlowLayout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 300
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
