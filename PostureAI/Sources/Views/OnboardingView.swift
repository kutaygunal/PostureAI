import SwiftUI

struct OnboardingView: View {
    @Binding var currentStep: Int
    @EnvironmentObject var appState: AppState

    private let totalSteps = 3

    private let stepTexts: [(title: String, subtitle: String)] = [
        (
            "Place the phone on a desk straight up with limited angle",
            "Position your device so the camera faces you at eye level."
        ),
        (
            "The camera will auto capture your front and side view",
            "We'll guide you through capturing both angles for complete analysis."
        ),
        (
            "Stand in the frame. Hold still to auto-capture.",
            "Position yourself within the guide outline and remain still for scanning."
        )
    ]

    var body: some View {
        ZStack {
            // Background
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Progress indicator
                HStack(spacing: 12) {
                    ForEach(0..<totalSteps, id: \.self) { index in
                        Circle()
                            .fill(index <= currentStep ? Color.blue : Color.gray.opacity(0.5))
                            .frame(width: 10, height: 10)
                            .scaleEffect(index == currentStep ? 1.2 : 1.0)
                            .animation(.easeInOut(duration: 0.3), value: currentStep)
                    }
                }
                .padding(.top, 40)

                // Step indicator
                Text("Step \(currentStep + 1)/\(totalSteps)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)
                    .padding(.top, 8)

                Spacer()

                // Main content card
                VStack(spacing: 24) {
                    // Icon/Illustration
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.2))
                            .frame(width: 120, height: 120)

                        Image(systemName: iconForStep(currentStep))
                            .font(.system(size: 48))
                            .foregroundColor(.blue)
                    }

                    // Title
                    Text(stepTexts[currentStep].title)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    // Subtitle
                    Text(stepTexts[currentStep].subtitle)
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .padding(32)

                Spacer()

                // Bottom button
                VStack(spacing: 16) {
                    Button(action: {
                        if currentStep < totalSteps - 1 {
                            withAnimation {
                                currentStep += 1
                            }
                        } else {
                            appState.hasCompletedOnboarding = true
                        }
                    }) {
                        Text(currentStep == totalSteps - 1 ? "Get Started" : "Next")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.blue)
                            .cornerRadius(14)
                    }
                    .padding(.horizontal, 32)

                    // Skip button (only on first step)
                    if currentStep > 0 {
                        Button(action: {
                            appState.hasCompletedOnboarding = true
                        }) {
                            Text("Skip")
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                        }
                        .padding(.bottom, 16)
                    }
                }
                .padding(.bottom, 32)
            }
        }
    }

    private func iconForStep(_ step: Int) -> String {
        switch step {
        case 0:
            return "iphone.gen3"
        case 1:
            return "camera.viewfinder"
        case 2:
            return "figure.stand"
        default:
            return "questionmark.circle"
        }
    }
}

#Preview {
    OnboardingView(currentStep: .constant(0))
        .environmentObject(AppState())
}
