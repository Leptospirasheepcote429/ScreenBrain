import SwiftUI

// MARK: - OnboardingView

struct OnboardingView: View {

    @Bindable var aiService: AIService
    var onComplete: () -> Void

    @State private var step: OnboardingStep = .welcome
    @State private var selectedMode: AnalysisMode = .aiVision
    @State private var selectedProviderIndex: Int = 0
    @State private var apiKey: String = ""
    @State private var selectedModel: String = ""
    @State private var isTestingConnection: Bool = false
    @State private var connectionResult: String? = nil

    private enum OnboardingStep: Int, CaseIterable {
        case welcome, chooseMode, configureProvider, done
    }

    var body: some View {
        VStack(spacing: 0) {
            // Progress
            HStack(spacing: 4) {
                ForEach(OnboardingStep.allCases, id: \.rawValue) { s in
                    Capsule()
                        .fill(s.rawValue <= step.rawValue ? Color.blue : PlatformColor.tertiaryFill)
                        .frame(height: 3)
                }
            }
            .padding(.horizontal, 40)
            .padding(.top, 20)

            Spacer()

            // Content
            Group {
                switch step {
                case .welcome: welcomeStep
                case .chooseMode: chooseModeStep
                case .configureProvider: configureProviderStep
                case .done: doneStep
                }
            }
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))

            Spacer()

            // Navigation
            HStack {
                if step != .welcome {
                    Button("Back") {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            step = OnboardingStep(rawValue: step.rawValue - 1) ?? .welcome
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(PlatformColor.secondaryLabel)
                }

                Spacer()

                if step == .done {
                    Button("Get Started") {
                        finishSetup()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                } else if step == .chooseMode && selectedMode == .localOCR {
                    Button("Finish Setup") {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            step = .done
                        }
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Continue") {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            step = OnboardingStep(rawValue: step.rawValue + 1) ?? .done
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(step == .configureProvider && apiKey.isEmpty)
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 30)
        }
        .frame(width: 560, height: 460)
    }

    // MARK: - Welcome

    private var welcomeStep: some View {
        VStack(spacing: 20) {
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.purple.opacity(0.8), Color.blue.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: "brain.head.profile")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 8) {
                Text("Welcome to ScreenBrain")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(PlatformColor.label)

                Text("Your AI-powered screenshot knowledge base.\nFind any screenshot by what's in it, not when you took it.")
                    .font(.system(size: 14))
                    .foregroundStyle(PlatformColor.secondaryLabel)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }

            VStack(alignment: .leading, spacing: 12) {
                featureRow(icon: "sparkles", color: .purple, text: "AI categorizes and describes your screenshots")
                featureRow(icon: "magnifyingglass", color: .blue, text: "Search by content, not just file names")
                featureRow(icon: "eye.slash", color: .green, text: "Everything stays on your Mac. Private by default.")
                featureRow(icon: "bolt", color: .orange, text: "Works offline with local OCR, or use any AI provider")
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, 40)
    }

    private func featureRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 24)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(PlatformColor.label)
        }
    }

    // MARK: - Choose Mode

    private var chooseModeStep: some View {
        VStack(spacing: 20) {
            Text("How should ScreenBrain analyze screenshots?")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(PlatformColor.label)
                .multilineTextAlignment(.center)

            VStack(spacing: 12) {
                modeCard(
                    mode: .aiVision,
                    title: "AI Vision",
                    subtitle: "Rich descriptions, smart categorization, OCR",
                    icon: "sparkles",
                    detail: "Requires an API key from OpenAI, OpenRouter, or a local Ollama server."
                )

                modeCard(
                    mode: .localOCR,
                    title: "Local OCR Only",
                    subtitle: "On-device text extraction, no API needed",
                    icon: "desktopcomputer",
                    detail: "Free, private, works offline. Categories assigned by text heuristics."
                )
            }
        }
        .padding(.horizontal, 40)
    }

    private func modeCard(mode: AnalysisMode, title: String, subtitle: String, icon: String, detail: String) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.15)) {
                selectedMode = mode
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(selectedMode == mode ? .white : PlatformColor.secondaryLabel)
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(selectedMode == mode ? Color.blue : PlatformColor.tertiaryFill)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(PlatformColor.label)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(PlatformColor.secondaryLabel)
                    Text(detail)
                        .font(.system(size: 10))
                        .foregroundStyle(PlatformColor.tertiaryLabel)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: selectedMode == mode ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(selectedMode == mode ? .blue : PlatformColor.tertiaryLabel)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(PlatformColor.secondaryBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(selectedMode == mode ? Color.blue.opacity(0.5) : .clear, lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Configure Provider

    private var configureProviderStep: some View {
        VStack(spacing: 20) {
            Text("Set up your AI provider")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(PlatformColor.label)

            VStack(alignment: .leading, spacing: 14) {
                // Provider picker
                Text("Provider")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(PlatformColor.secondaryLabel)
                    .textCase(.uppercase)
                    .tracking(0.5)

                Picker("", selection: $selectedProviderIndex) {
                    ForEach(Array(APIProvider.builtInProviders.enumerated()), id: \.offset) { index, provider in
                        Text(provider.name).tag(index)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: selectedProviderIndex) { _, newValue in
                    let provider = APIProvider.builtInProviders[newValue]
                    if let first = provider.models.first {
                        selectedModel = first
                    }
                }

                // API Key
                VStack(alignment: .leading, spacing: 4) {
                    Text("API Key")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(PlatformColor.secondaryLabel)
                        .textCase(.uppercase)
                        .tracking(0.5)

                    SecureField("Paste your API key here", text: $apiKey)
                        .font(.system(size: 13, design: .monospaced))
                        .textFieldStyle(.roundedBorder)
                }

                // Model
                VStack(alignment: .leading, spacing: 4) {
                    Text("Model")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(PlatformColor.secondaryLabel)
                        .textCase(.uppercase)
                        .tracking(0.5)

                    let provider = APIProvider.builtInProviders[selectedProviderIndex]
                    Picker("", selection: $selectedModel) {
                        ForEach(provider.models, id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }
                    .pickerStyle(.menu)
                }

                // Test connection
                if !apiKey.isEmpty {
                    HStack {
                        Button {
                            Task { await testConnection() }
                        } label: {
                            HStack(spacing: 6) {
                                if isTestingConnection {
                                    ProgressView().scaleEffect(0.6)
                                } else {
                                    Image(systemName: "bolt.fill")
                                        .font(.system(size: 11))
                                }
                                Text(isTestingConnection ? "Testing..." : "Test Connection")
                                    .font(.system(size: 12, weight: .medium))
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(isTestingConnection)

                        if let result = connectionResult {
                            Text(result)
                                .font(.system(size: 11))
                                .foregroundStyle(result.contains("Success") ? .green : .red)
                        }
                    }
                }
            }
            .padding(.horizontal, 4)

            Text("Your API key is stored locally on your Mac and never sent anywhere except the provider you choose.")
                .font(.system(size: 10))
                .foregroundStyle(PlatformColor.tertiaryLabel)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 40)
        .onAppear {
            if let first = APIProvider.builtInProviders.first?.models.first {
                selectedModel = first
            }
        }
    }

    // MARK: - Done

    private var doneStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)

            Text("You're all set!")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(PlatformColor.label)

            VStack(spacing: 6) {
                Text("Mode: \(selectedMode == .aiVision ? "AI Vision" : "Local OCR")")
                    .font(.system(size: 13))
                    .foregroundStyle(PlatformColor.secondaryLabel)

                if selectedMode == .aiVision {
                    Text("Provider: \(APIProvider.builtInProviders[selectedProviderIndex].name)")
                        .font(.system(size: 13))
                        .foregroundStyle(PlatformColor.secondaryLabel)
                    Text("Model: \(selectedModel)")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(PlatformColor.tertiaryLabel)
                }
            }

            Text("Click the + button to import screenshots from Photos.\nYou can change these settings anytime.")
                .font(.system(size: 12))
                .foregroundStyle(PlatformColor.tertiaryLabel)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
        }
    }

    // MARK: - Actions

    private func testConnection() async {
        isTestingConnection = true
        connectionResult = nil

        let provider = APIProvider.builtInProviders[selectedProviderIndex]
        var testProvider = provider
        testProvider.apiKey = apiKey

        // Save temporarily for the test
        let previousProviders = aiService.providers
        let previousProviderID = aiService.selectedProviderID
        let previousModel = aiService.selectedModel

        aiService.providers = [testProvider]
        aiService.selectedProviderID = testProvider.id.uuidString
        aiService.selectedModel = selectedModel
        aiService.analysisMode = .aiVision

        do {
            // Simple text-only test
            var request = URLRequest(url: URL(string: testProvider.endpoint)!)
            request.httpMethod = "POST"
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let body: [String: Any] = [
                "model": selectedModel,
                "messages": [["role": "user", "content": "Say OK"]],
                "max_tokens": 5
            ]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            request.timeoutInterval = 15

            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                connectionResult = "Success! Connection works."
            } else {
                connectionResult = "Failed: unexpected response"
            }
        } catch {
            connectionResult = "Failed: \(error.localizedDescription)"
        }

        // Restore
        aiService.providers = previousProviders
        aiService.selectedProviderID = previousProviderID
        aiService.selectedModel = previousModel

        isTestingConnection = false
    }

    private func finishSetup() {
        aiService.analysisMode = selectedMode

        if selectedMode == .aiVision {
            var provider = APIProvider.builtInProviders[selectedProviderIndex]
            provider.apiKey = apiKey

            var allProviders = APIProvider.builtInProviders
            allProviders[selectedProviderIndex] = provider
            aiService.providers = allProviders
            aiService.selectedProviderID = provider.id.uuidString
            aiService.selectedModel = selectedModel
        }

        aiService.hasCompletedSetup = true
        onComplete()
    }
}
