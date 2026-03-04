import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var currentStep = 0
    @State private var transitionOpacity = 1.0
    @State private var useEnhancedUI = true  // Toggle to switch between original and enhanced

    var body: some View {
        ZStack {
            // Background gradient that persists
            LinearGradient(
                colors: [Color.black, Color(red: 0.05, green: 0.05, blue: 0.1)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // Main content with transition
            Group {
                if appState.hasCompletedOnboarding {
                    NavigationStack {
                        if useEnhancedUI {
                            EnhancedScanView()
                        } else {
                            ScanView()  // Original fallback
                        }
                    }
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .opacity))
                } else {
                    if useEnhancedUI {
                        EnhancedOnboardingView(currentStep: $currentStep)
                            .transition(.asymmetric(insertion: .opacity, removal: .move(edge: .leading)))
                    } else {
                        OnboardingView(currentStep: $currentStep)
                            .transition(.asymmetric(insertion: .opacity, removal: .move(edge: .leading)))
                    }
                }
            }
            .opacity(transitionOpacity)
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: appState.hasCompletedOnboarding)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
