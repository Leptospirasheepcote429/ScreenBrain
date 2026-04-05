import SwiftUI
import SwiftData

// MARK: - SettingsView

struct SettingsView: View {

    @Bindable var aiService: AIService

    @Environment(\.modelContext) private var modelContext

    @State private var showReanalyzeAlert: Bool = false
    @State private var showClearDataAlert: Bool = false
    @State private var isReanalyzing: Bool = false
    @State private var screenshotStats: ScreenshotStats = .empty
    @State private var showAddProvider: Bool = false

    // Local editing state synced from aiService on appear
    @State private var analysisMode: AnalysisMode = .aiVision
    @State private var selectedProviderID: String = ""
    @State private var selectedModel: String = ""
    @State private var providers: [APIProvider] = []

    var body: some View {
        Form {
            aboutSection
            analysisModeSection
            if analysisMode == .aiVision {
                providerSection
                modelSection
            }
            statisticsSection
            librarySection
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .onAppear { loadState() }
        .sheet(isPresented: $showAddProvider) {
            AddProviderSheet { newProvider in
                providers.append(newProvider)
                aiService.providers = providers
                selectedProviderID = newProvider.id.uuidString
                aiService.selectedProviderID = selectedProviderID
                if let firstModel = newProvider.models.first {
                    selectedModel = firstModel
                    aiService.selectedModel = firstModel
                }
            }
        }
    }

    private func loadState() {
        analysisMode = aiService.analysisMode
        providers = aiService.providers
        selectedProviderID = aiService.selectedProviderID
        selectedModel = aiService.selectedModel
        loadStats()
    }

    private var activeProvider: APIProvider {
        providers.first { $0.id.uuidString == selectedProviderID }
            ?? APIProvider.builtInProviders.first
            ?? APIProvider(id: UUID(), name: "Custom", endpoint: "", apiKey: "", models: [])
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.purple, Color.blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 52, height: 52)

                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 26, weight: .medium))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("ScreenBrain")
                        .font(.headline)
                        .foregroundStyle(PlatformColor.label)

                    Text("AI-powered screenshot organizer")
                        .font(.caption)
                        .foregroundStyle(PlatformColor.secondaryLabel)

                    Text("Version \(appVersion)")
                        .font(.caption2)
                        .foregroundStyle(PlatformColor.tertiaryLabel)
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("About")
        }
    }

    // MARK: - Analysis Mode Section

    private var analysisModeSection: some View {
        Section {
            Picker("Analysis Mode", selection: $analysisMode) {
                ForEach(AnalysisMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: analysisMode) { _, newValue in
                aiService.analysisMode = newValue
            }

            if analysisMode == .localOCR {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.blue)
                        .font(.system(size: 13))
                    Text("Local OCR uses Apple Vision for text extraction. Categories and tags are assigned via heuristics. No API key or internet required.")
                        .font(.caption)
                        .foregroundStyle(PlatformColor.secondaryLabel)
                }
            }
        } header: {
            Text("Analysis Mode")
        } footer: {
            Text("Local OCR works offline. AI Vision gives richer descriptions but needs an API.")
                .font(.caption)
        }
    }

    // MARK: - Provider Section

    private var providerSection: some View {
        Section {
            Picker("API Provider", selection: $selectedProviderID) {
                ForEach(providers) { provider in
                    Text(provider.name).tag(provider.id.uuidString)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: selectedProviderID) { _, newValue in
                aiService.selectedProviderID = newValue
                // Auto-select first model of new provider
                if let provider = providers.first(where: { $0.id.uuidString == newValue }),
                   let first = provider.models.first {
                    selectedModel = first
                    aiService.selectedModel = first
                }
            }

            // API Key for active provider
            VStack(alignment: .leading, spacing: 6) {
                Text("API Key")
                    .font(.caption)
                    .foregroundStyle(PlatformColor.secondaryLabel)

                let binding = Binding<String>(
                    get: { activeProvider.apiKey },
                    set: { newKey in
                        if let idx = providers.firstIndex(where: { $0.id.uuidString == selectedProviderID }) {
                            providers[idx].apiKey = newKey
                            aiService.providers = providers
                        }
                    }
                )

                SecureField("Enter API key", text: binding)
                    .autocorrectionDisabled()
                    .font(.system(size: 12, design: .monospaced))
            }

            // Custom endpoint
            VStack(alignment: .leading, spacing: 6) {
                Text("Endpoint")
                    .font(.caption)
                    .foregroundStyle(PlatformColor.secondaryLabel)

                let endpointBinding = Binding<String>(
                    get: { activeProvider.endpoint },
                    set: { newEndpoint in
                        if let idx = providers.firstIndex(where: { $0.id.uuidString == selectedProviderID }) {
                            providers[idx].endpoint = newEndpoint
                            aiService.providers = providers
                        }
                    }
                )

                TextField("https://api.example.com/v1/chat/completions", text: endpointBinding)
                    .autocorrectionDisabled()
                    .font(.system(size: 11, design: .monospaced))
            }

            Button {
                showAddProvider = true
            } label: {
                Label("Add Custom Provider", systemImage: "plus.circle")
            }

            // Delete custom providers (not the built-in ones)
            let builtInIDs = Set(APIProvider.builtInProviders.map(\.id))
            if !builtInIDs.contains(activeProvider.id) {
                Button(role: .destructive) {
                    providers.removeAll { $0.id.uuidString == selectedProviderID }
                    aiService.providers = providers
                    if let first = providers.first {
                        selectedProviderID = first.id.uuidString
                        aiService.selectedProviderID = selectedProviderID
                    }
                } label: {
                    Label("Remove This Provider", systemImage: "trash")
                        .foregroundStyle(.red)
                }
            }
        } header: {
            Text("API Provider")
        } footer: {
            Text("Bring your own API key. Supports any OpenAI-compatible endpoint.")
                .font(.caption)
        }
    }

    // MARK: - Model Section

    private var modelSection: some View {
        Section {
            Picker("Model", selection: $selectedModel) {
                ForEach(activeProvider.models, id: \.self) { model in
                    Text(model)
                        .font(.system(size: 13, design: .monospaced))
                        .tag(model)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: selectedModel) { _, newValue in
                aiService.selectedModel = newValue
            }

            // Custom model name input
            VStack(alignment: .leading, spacing: 6) {
                Text("Or enter a custom model name")
                    .font(.caption)
                    .foregroundStyle(PlatformColor.tertiaryLabel)

                HStack {
                    TextField("e.g. anthropic/claude-opus-4.6", text: $selectedModel)
                        .autocorrectionDisabled()
                        .font(.system(size: 11, design: .monospaced))
                        .onSubmit {
                            aiService.selectedModel = selectedModel
                        }

                    Button("Set") {
                        aiService.selectedModel = selectedModel
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        } header: {
            Text("AI Model")
        }
    }

    // MARK: - Statistics Section

    private var statisticsSection: some View {
        Section {
            HStack {
                Label("Total Screenshots", systemImage: "photo.stack")
                    .foregroundStyle(PlatformColor.label)
                Spacer()
                Text("\(screenshotStats.total)")
                    .foregroundStyle(PlatformColor.secondaryLabel)
                    .monospacedDigit()
            }

            HStack {
                Label("Analyzed", systemImage: "sparkles")
                    .foregroundStyle(PlatformColor.label)
                Spacer()
                Text("\(screenshotStats.analyzed)")
                    .foregroundStyle(PlatformColor.secondaryLabel)
                    .monospacedDigit()
            }

            HStack {
                Label("Storage Used", systemImage: "internaldrive")
                    .foregroundStyle(PlatformColor.label)
                Spacer()
                Text(screenshotStats.storageString)
                    .foregroundStyle(PlatformColor.secondaryLabel)
            }

            if !screenshotStats.byCategory.isEmpty {
                ForEach(screenshotStats.byCategory, id: \.category) { entry in
                    HStack(spacing: 10) {
                        Image(systemName: entry.category.icon)
                            .font(.system(size: 13))
                            .foregroundStyle(entry.category.color)
                            .frame(width: 20)

                        Text(entry.category.rawValue)
                            .font(.subheadline)
                            .foregroundStyle(PlatformColor.label)

                        Spacer()

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(PlatformColor.tertiaryFill)
                                    .frame(height: 6)

                                let fraction = screenshotStats.total > 0
                                    ? CGFloat(entry.count) / CGFloat(screenshotStats.total)
                                    : 0
                                Capsule()
                                    .fill(entry.category.color)
                                    .frame(width: geo.size.width * fraction, height: 6)
                            }
                        }
                        .frame(width: 80, height: 6)
                        .padding(.trailing, 6)

                        Text("\(entry.count)")
                            .font(.caption)
                            .foregroundStyle(PlatformColor.secondaryLabel)
                            .monospacedDigit()
                            .frame(minWidth: 24, alignment: .trailing)
                    }
                }
            }
        } header: {
            Text("Statistics")
        }
    }

    // MARK: - Library Section

    private var librarySection: some View {
        Section {
            Button {
                showReanalyzeAlert = true
            } label: {
                if isReanalyzing {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Re-analyzing...")
                            .foregroundStyle(PlatformColor.secondaryLabel)
                    }
                } else {
                    Label("Re-analyze All Screenshots", systemImage: "arrow.clockwise.circle")
                        .foregroundStyle(PlatformColor.label)
                }
            }
            .disabled(isReanalyzing)
            .alert("Re-analyze All Screenshots?", isPresented: $showReanalyzeAlert) {
                Button("Re-analyze") {
                    Task { await reanalyzeAll() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will re-run analysis on all \(screenshotStats.total) screenshots using the current mode (\(analysisMode.rawValue)).")
            }

            Button(role: .destructive) {
                showClearDataAlert = true
            } label: {
                Label("Clear All Data", systemImage: "trash")
                    .foregroundStyle(.red)
            }
            .alert("Clear All Data?", isPresented: $showClearDataAlert) {
                Button("Delete Everything", role: .destructive) {
                    clearAllData()
                    HapticFeedback.warning()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete all \(screenshotStats.total) screenshots from ScreenBrain. Your original photos will not be affected.")
            }
        } header: {
            Text("Library")
        }
    }

    // MARK: - Helpers

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private func loadStats() {
        let descriptor = FetchDescriptor<Screenshot>()
        let all = (try? modelContext.fetch(descriptor)) ?? []

        let analyzed = all.filter { $0.isAnalyzed }.count
        let storageBytes = all.reduce(0) { $0 + $1.imageData.count }

        var countByCategory: [Category: Int] = [:]
        for shot in all {
            countByCategory[shot.categoryEnum, default: 0] += 1
        }

        let byCategory = Category.allCases
            .compactMap { cat -> CategoryStat? in
                guard let count = countByCategory[cat], count > 0 else { return nil }
                return CategoryStat(category: cat, count: count)
            }
            .sorted { $0.count > $1.count }

        screenshotStats = ScreenshotStats(
            total: all.count,
            analyzed: analyzed,
            storageBytes: storageBytes,
            byCategory: byCategory
        )
    }

    @MainActor
    private func reanalyzeAll() async {
        isReanalyzing = true

        let descriptor = FetchDescriptor<Screenshot>()
        let all = (try? modelContext.fetch(descriptor)) ?? []

        for screenshot in all {
            do {
                let result = try await aiService.analyzeScreenshot(imageData: screenshot.imageData)
                screenshot.ocrText = result.ocrText
                screenshot.aiDescription = result.description
                screenshot.category = result.category
                screenshot.tags = result.tags
                screenshot.sourceApp = result.sourceApp
                screenshot.analyzedAt = Date()
                screenshot.isAnalyzed = true
                try? modelContext.save()
            } catch {
                // Skip failed, continue
            }
        }

        isReanalyzing = false
        loadStats()
    }

    private func clearAllData() {
        let descriptor = FetchDescriptor<Screenshot>()
        let all = (try? modelContext.fetch(descriptor)) ?? []
        for screenshot in all {
            modelContext.delete(screenshot)
        }
        try? modelContext.save()
        loadStats()
    }
}

// MARK: - AddProviderSheet

private struct AddProviderSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var endpoint: String = ""
    @State private var apiKey: String = ""
    @State private var modelsText: String = ""

    let onAdd: (APIProvider) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Text("Add API Provider")
                    .font(.headline)
                Spacer()
                Button("Add") {
                    let models = modelsText
                        .components(separatedBy: "\n")
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty }
                    let provider = APIProvider(
                        id: UUID(),
                        name: name,
                        endpoint: endpoint,
                        apiKey: apiKey,
                        models: models.isEmpty ? ["default"] : models
                    )
                    onAdd(provider)
                    dismiss()
                }
                .disabled(name.isEmpty || endpoint.isEmpty)
            }
            .padding()

            Divider()

            Form {
                Section("Provider Details") {
                    TextField("Name (e.g. My Server)", text: $name)
                    TextField("Endpoint URL", text: $endpoint)
                        .font(.system(size: 12, design: .monospaced))
                    SecureField("API Key", text: $apiKey)
                }

                Section("Models (one per line)") {
                    TextEditor(text: $modelsText)
                        .font(.system(size: 12, design: .monospaced))
                        .frame(minHeight: 80)
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 480, height: 420)
    }
}

// MARK: - Stats Models

private struct ScreenshotStats {
    let total: Int
    let analyzed: Int
    let storageBytes: Int
    let byCategory: [CategoryStat]

    static let empty = ScreenshotStats(total: 0, analyzed: 0, storageBytes: 0, byCategory: [])

    var storageString: String {
        let mb = Double(storageBytes) / 1_048_576
        if mb < 1 {
            return String(format: "%.0f KB", Double(storageBytes) / 1024)
        } else if mb < 1024 {
            return String(format: "%.1f MB", mb)
        } else {
            return String(format: "%.1f GB", mb / 1024)
        }
    }
}

private struct CategoryStat {
    let category: Category
    let count: Int
}
