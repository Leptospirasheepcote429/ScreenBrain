import SwiftUI
import SwiftData

@main
struct ScreenBrainApp: App {

    @State private var aiService = AIService()

    var body: some Scene {
        WindowGroup {
            RootView(aiService: aiService)
        }
        .modelContainer(for: Screenshot.self)
        #if os(macOS)
        .defaultSize(width: 1100, height: 700)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .sidebar) {
                Button("Import from Photos") {
                    NotificationCenter.default.post(name: .importScreenshots, object: nil)
                }
                .keyboardShortcut("i", modifiers: .command)
            }
        }
        #endif
    }
}

// MARK: - RootView

struct RootView: View {
    @Bindable var aiService: AIService
    @State private var showOnboarding: Bool = false

    var body: some View {
        ContentView(aiService: aiService)
            .sheet(isPresented: $showOnboarding) {
                OnboardingView(aiService: aiService) {
                    showOnboarding = false
                }
            }
            .onAppear {
                if !aiService.hasCompletedSetup {
                    showOnboarding = true
                }
            }
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let importScreenshots = Notification.Name("importScreenshots")
}
