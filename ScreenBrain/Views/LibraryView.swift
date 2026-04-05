import SwiftUI
import SwiftData

// MARK: - LibraryView

struct LibraryView: View {

    @Environment(\.modelContext) private var modelContext
    @Bindable var viewModel: LibraryViewModel
    var photosService: PhotosService
    var aiService: AIService

    @State private var selectedScreenshot: Screenshot? = nil
    @State private var viewMode: ViewMode = .grid

    private var gridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 170, maximum: 240), spacing: 12)]
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                VStack(spacing: 0) {
                    // Toolbar area with category chips
                    categoryFilterBar
                        .padding(.top, 8)
                        .padding(.bottom, 10)

                    Divider()
                        .opacity(0.5)

                    // Content
                    ScrollView {
                        switch viewMode {
                        case .grid:
                            screenshotGrid
                                .padding(.top, 12)
                        case .list:
                            screenshotList
                                .padding(.top, 4)
                        }
                    }
                    .scrollIndicators(.automatic)
                }

                importFAB
                    .padding(.trailing, 24)
                    .padding(.bottom, 28)
            }
            .navigationTitle("Library")
            .toolbar {
                ToolbarItemGroup(placement: .automatic) {
                    viewModeToggle
                    Divider()
                        .frame(height: 16)
                    sortMenu
                }
            }
            .onAppear {
                viewModel.loadScreenshots(context: modelContext)
            }
            .overlay {
                if viewModel.isImporting {
                    importOverlay
                }
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage)
            }
            .sheet(isPresented: $viewModel.showImportConfirmation) {
                ImportConfirmationSheet(
                    count: viewModel.pendingImportCount,
                    onImport: { limit in
                        Task {
                            await viewModel.importFromPhotos(
                                photosService: photosService,
                                aiService: aiService,
                                context: modelContext,
                                limit: limit
                            )
                        }
                    },
                    onCancel: {
                        viewModel.showImportConfirmation = false
                    }
                )
            }
            .navigationDestination(item: $selectedScreenshot) { screenshot in
                DetailView(
                    screenshot: screenshot,
                    onDelete: {
                        viewModel.deleteScreenshot(screenshot, context: modelContext)
                        selectedScreenshot = nil
                    }
                )
            }
        }
    }

    // MARK: - View Mode Toggle

    private var viewModeToggle: some View {
        HStack(spacing: 1) {
            ForEach(ViewMode.allCases, id: \.rawValue) { mode in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        viewMode = mode
                    }
                } label: {
                    Image(systemName: mode.icon)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(viewMode == mode ? PlatformColor.label : PlatformColor.tertiaryLabel)
                        .frame(width: 26, height: 20)
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(viewMode == mode ? PlatformColor.secondaryBackground : .clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(PlatformColor.tertiaryFill)
        )
    }

    // MARK: - Category Filter Bar

    private var categoryFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                CategoryChip(
                    label: "All",
                    icon: "square.grid.2x2",
                    color: PlatformColor.label,
                    isSelected: viewModel.selectedCategory == nil
                ) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        viewModel.filterByCategory(nil, context: modelContext)
                    }
                }

                ForEach(Category.allCases) { category in
                    CategoryChip(
                        label: category.rawValue,
                        icon: category.icon,
                        color: category.color,
                        isSelected: viewModel.selectedCategory == category
                    ) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            viewModel.filterByCategory(category, context: modelContext)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Screenshot Grid

    @ViewBuilder
    private var screenshotGrid: some View {
        if viewModel.screenshots.isEmpty && !viewModel.isImporting {
            emptyState
                .frame(maxWidth: .infinity)
                .padding(.top, 100)
        } else {
            LazyVGrid(columns: gridColumns, spacing: 12) {
                ForEach(viewModel.screenshots) { screenshot in
                    ScreenshotCard(screenshot: screenshot)
                        .onTapGesture {
                            selectedScreenshot = screenshot
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
            }
            .padding(.horizontal, 16)
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: viewModel.screenshots.map(\.id))
            .padding(.bottom, 100)
        }
    }

    // MARK: - Screenshot List

    @ViewBuilder
    private var screenshotList: some View {
        if viewModel.screenshots.isEmpty && !viewModel.isImporting {
            emptyState
                .frame(maxWidth: .infinity)
                .padding(.top, 100)
        } else {
            // Column header
            HStack(spacing: 0) {
                Text("")
                    .frame(width: 60, alignment: .leading)
                Text("Description")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Category")
                    .frame(width: 110, alignment: .leading)
                Text("Date")
                    .frame(width: 130, alignment: .leading)
                Text("Status")
                    .frame(width: 50, alignment: .center)
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(PlatformColor.tertiaryLabel)
            .textCase(.uppercase)
            .tracking(0.5)
            .padding(.horizontal, 16)
            .padding(.vertical, 5)

            Divider()
                .opacity(0.4)

            LazyVStack(spacing: 0) {
                ForEach(viewModel.screenshots) { screenshot in
                    ScreenshotListRow(screenshot: screenshot)
                        .onTapGesture {
                            selectedScreenshot = screenshot
                        }
                        .transition(.opacity)
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: viewModel.screenshots.map(\.id))
            .padding(.bottom, 100)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48, weight: .ultraLight))
                .foregroundStyle(PlatformColor.tertiaryLabel)

            VStack(spacing: 6) {
                Text("No screenshots yet")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(PlatformColor.label)

                Text("Click + to import from Photos")
                    .font(.system(size: 13))
                    .foregroundStyle(PlatformColor.tertiaryLabel)
            }
        }
    }

    // MARK: - Import FAB

    private var importFAB: some View {
        Button {
            Task {
                await viewModel.previewImport(
                    photosService: photosService,
                    context: modelContext
                )
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.blue, Color.purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: Color.blue.opacity(0.35), radius: 12, x: 0, y: 6)
                )
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isImporting)
        .opacity(viewModel.isImporting ? 0.5 : 1.0)
        .scaleEffect(viewModel.isImporting ? 0.9 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.isImporting)
    }

    // MARK: - Import Overlay

    private var importOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .background(.ultraThinMaterial)

            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(.white)

                Text("Importing Screenshots")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)

                VStack(spacing: 8) {
                    ProgressView(value: viewModel.importProgress)
                        .progressViewStyle(.linear)
                        .tint(.white)
                        .frame(width: 200)

                    Text("\(Int(viewModel.importProgress * 100))%")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.2), radius: 30, x: 0, y: 10)
            )
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.3), value: viewModel.isImporting)
    }

    // MARK: - Sort Menu

    private var sortMenu: some View {
        Menu {
            ForEach(SortOrder.allCases) { order in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        viewModel.sortOrder = order
                        viewModel.loadScreenshots(context: modelContext)
                    }
                } label: {
                    if viewModel.sortOrder == order {
                        Label(order.rawValue, systemImage: "checkmark")
                    } else {
                        Text(order.rawValue)
                    }
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(PlatformColor.secondaryLabel)
        }
    }
}

// MARK: - CategoryChip

private struct CategoryChip: View {
    let label: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                Text(label)
                    .font(.system(size: 11, weight: .medium))
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isSelected ? color.opacity(0.85) : (isHovered ? PlatformColor.tertiaryFill : PlatformColor.secondaryBackground))
            )
            .foregroundStyle(isSelected ? .white : PlatformColor.secondaryLabel)
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.15), value: isSelected)
        .animation(.easeOut(duration: 0.1), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - ImportConfirmationSheet

private struct ImportConfirmationSheet: View {
    let count: Int
    let onImport: (Int?) -> Void
    let onCancel: () -> Void

    @State private var selectedOption: ImportOption = .all

    private enum ImportOption: Hashable {
        case all
        case recent25
        case recent50
        case recent100
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.2), Color.purple.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)

                    Image(systemName: "photo.stack")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                Text("Import Screenshots")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(PlatformColor.label)

                Text("Found **\(count)** new screenshot\(count == 1 ? "" : "s") in your Photos library.")
                    .font(.system(size: 13))
                    .foregroundStyle(PlatformColor.secondaryLabel)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 28)
            .padding(.bottom, 20)
            .padding(.horizontal, 24)

            Divider().opacity(0.5)

            // Options
            VStack(spacing: 2) {
                importOption(
                    label: "Import all \(count) screenshots",
                    subtitle: "Full import with AI analysis",
                    icon: "square.and.arrow.down.on.square",
                    option: .all
                )

                if count > 25 {
                    importOption(
                        label: "Import latest 25",
                        subtitle: "Most recent screenshots only",
                        icon: "clock.arrow.circlepath",
                        option: .recent25
                    )
                }

                if count > 50 {
                    importOption(
                        label: "Import latest 50",
                        subtitle: "Recent screenshots",
                        icon: "clock.arrow.circlepath",
                        option: .recent50
                    )
                }

                if count > 100 {
                    importOption(
                        label: "Import latest 100",
                        subtitle: "A larger batch",
                        icon: "clock.arrow.circlepath",
                        option: .recent100
                    )
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)

            Divider().opacity(0.5)

            // Buttons
            HStack(spacing: 12) {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.bordered)
                .controlSize(.regular)

                Button("Import") {
                    let limit: Int?
                    switch selectedOption {
                    case .all: limit = nil
                    case .recent25: limit = 25
                    case .recent50: limit = 50
                    case .recent100: limit = 100
                    }
                    onImport(limit)
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 24)
        }
        .frame(width: 380)
        .background(.regularMaterial)
    }

    private func importOption(label: String, subtitle: String, icon: String, option: ImportOption) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.15)) {
                selectedOption = option
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundStyle(selectedOption == option ? .blue : PlatformColor.secondaryLabel)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(PlatformColor.label)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(PlatformColor.tertiaryLabel)
                }

                Spacer()

                Image(systemName: selectedOption == option ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(selectedOption == option ? .blue : PlatformColor.tertiaryLabel)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(selectedOption == option ? Color.blue.opacity(0.08) : .clear)
            )
        }
        .buttonStyle(.plain)
    }
}
