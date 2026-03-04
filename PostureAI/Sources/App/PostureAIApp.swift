import SwiftUI
import Combine

@main
struct PostureAIApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
    }
}

class AppState: ObservableObject {
    @Published var hasCompletedOnboarding: Bool {
        didSet {
            UserDefaults.standard.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding")
        }
    }

    @Published var capturedFrontImageURL: URL?
    @Published var capturedSideImageURL: URL?
    @Published var userHeightCm: Double = 170.0

    init() {
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    }

    func reset() {
        capturedFrontImageURL = nil
        capturedSideImageURL = nil
        userHeightCm = 170.0
    }
}
