import SwiftUI

// MARK: - Enhanced Onboarding View with Modern UI/UX

struct EnhancedOnboardingView: View {
    @Binding var currentStep: Int
    @EnvironmentObject var appState: AppState
    @State private var dragOffset: CGFloat = 0
    @State private var scale: CGFloat = 1.0
    @State private var contentOpacity: Double = 1.0
    
    private let totalSteps = 3
    
    private let onboardingData: [OnboardingStep] = [
        OnboardingStep(
            title: "Position Your Device",
            subtitle: "Place your iPhone on a stable surface at eye level for the best results.",
            icon: "checkmark.shield.fill",
            color: .blue,
            features: [
                Feature(icon: "iphone", text: "Stable surface"),
                Feature(icon: "eye.fill", text: "Eye level"),
                Feature(icon: "person.fill", text: "Full body visible")
            ]
        ),
        OnboardingStep(
            title: "Auto Capture",
            subtitle: "Our AI detects your pose and automatically captures front and side views.",
            icon: "camera.fill",
            color: .cyan,
            features: [
                Feature(icon: "hand.raised.fill", text: "No button needed"),
                Feature(icon: "wand.and.stars", text: "AI powered"),
                Feature(icon: "clock.fill", text: "3 sec countdown")
            ]
        ),
        OnboardingStep(
            title: "Posture Analysis",
            subtitle: "Get detailed insights about your posture with personalized recommendations.",
            icon: "chart.bar.fill",
            color: .green,
            features: [
                Feature(icon: "ruler.fill", text: "Angle measurements"),
                Feature(icon: "doc.text.fill", text: "Detailed report"),
                Feature(icon: "person.crop.circle.badge.checkmark", text: "Improvement tips")
            ]
        )
    ]
    
    var body: some View {
        ZStack {
            // Animated background gradient
            AnimatedBackground(step: currentStep)
                .ignoresSafeArea()
            
            // Content
            VStack(spacing: 0) {
                // Skip button
                HStack {
                    Spacer()
                    Button(action: { skipOnboarding() }) {
                        Text("Skip")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                    }
                }
                .padding(.top, 16)
                .padding(.horizontal)
                
                // Progress dots
                HStack(spacing: 10) {
                    ForEach(0..<totalSteps, id: \.self) { index in
                        OnboardingDot(
                            isActive: index == currentStep,
                            isCompleted: index < currentStep
                        )
                    }
                }
                .padding(.vertical, 20)
                
                // Step indicator
                Text("Step \(currentStep + 1) of \(totalSteps)")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
                    .tracking(1)
                    .padding(.bottom, 20)
                
                // Main content with horizontal swipe
                TabView(selection: $currentStep) {
                    ForEach(0..<totalSteps, id: \.self) { index in
                        OnboardingContent(step: onboardingData[index])
                            .tag(index)
                            .scaleEffect(currentStep == index ? 1.0 : 0.9)
                            .opacity(currentStep == index ? 1.0 : 0.5)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentStep)
                
                Spacer()
                
                // Bottom buttons
                VStack(spacing: 16) {
                    Button(action: { nextStep() }) {
                        HStack(spacing: 8) {
                            Text(isLastStep ? "Get Started" : "Continue")
                                .font(.system(size: 17, weight: .semibold))
                            
                            Image(systemName: isLastStep ? "arrow.right.circle" : "chevron.right")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            LinearGradient(
                                colors: [
                                    onboardingData[currentStep].color,
                                    onboardingData[currentStep].color.opacity(0.8)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(
                            color: onboardingData[currentStep].color.opacity(0.4),
                            radius: 12,
                            x: 0,
                            y: 4
                        )
                    }
                    .onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity) {
                    } onPressingChanged: { pressing in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            scale = pressing ? 0.96 : 1.0
                        }
                        if pressing { HapticManager.shared.lightFeedback() }
                    }
                    .scaleEffect(scale)
                    
                    // Page indicators below button
                    HStack(spacing: 8) {
                        ForEach(0..<totalSteps, id: \.self) { index in
                            Capsule()
                                .fill(index == currentStep ? Color.white : Color.white.opacity(0.3))
                                .frame(width: index == currentStep ? 24 : 8, height: 8)
                                .animation(.spring(response: 0.3), value: currentStep)
                        }
                    }
                    .padding(.bottom, 16)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
            }
        }
    }
    
    private var isLastStep: Bool {
        currentStep == totalSteps - 1
    }
    
    private func nextStep() {
        HapticManager.shared.mediumFeedback()
        
        withAnimation(.easeOut(duration: 0.2)) {
            contentOpacity = 0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            if currentStep < totalSteps - 1 {
                currentStep += 1
            } else {
                completeOnboarding()
            }
            
            withAnimation(.easeIn(duration: 0.2)) {
                contentOpacity = 1
            }
        }
    }
    
    private func skipOnboarding() {
        HapticManager.shared.lightFeedback()
        completeOnboarding()
    }
    
    private func completeOnboarding() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            appState.hasCompletedOnboarding = true
        }
    }
}

// MARK: - Animated Background

struct AnimatedBackground: View {
    let step: Int
    @State private var rotation: Double = 0
    
    var gradientColors: [Color] {
        switch step {
        case 0: return [.blue.opacity(0.3), .purple.opacity(0.2), .black]
        case 1: return [.cyan.opacity(0.3), .blue.opacity(0.2), .black]
        case 2: return [.green.opacity(0.3), .cyan.opacity(0.2), .black]
        default: return [.blue.opacity(0.3), .purple.opacity(0.2), .black]
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Base gradient
                LinearGradient(
                    colors: [Color.black, Color(red: 0.08, green: 0.08, blue: 0.12)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                // Animated orbs
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [gradientColors[0].opacity(0.5), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 300
                            )
                        )
                        .frame(width: 400, height: 400)
                        .offset(x: -100, y: -200)
                        .blur(radius: 60)
                    
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [gradientColors[1].opacity(0.4), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 250
                            )
                        )
                        .frame(width: 350, height: 350)
                        .offset(x: 120, y: 100)
                        .blur(radius: 50)
                }
                .rotationEffect(.degrees(rotation))
                .onAppear {
                    withAnimation(.linear(duration: 20).repeatForever(autoreverses: true)) {
                        rotation = 360
                    }
                }
            }
        }
    }
}

// MARK: - Onboarding Dot

struct OnboardingDot: View {
    let isActive: Bool
    let isCompleted: Bool
    @State private var scale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            if isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 20))
            } else if isActive {
                Circle()
                    .fill(Color.white)
                    .frame(width: 10, height: 10)
                    .scaleEffect(scale)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                            scale = 1.3
                        }
                    }
            } else {
                Circle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isActive)
    }
}

// MARK: - Onboarding Content

struct OnboardingContent: View {
    let step: OnboardingStep
    @State private var iconScale: CGFloat = 0.5
    @State private var titleOffset: CGFloat = 30
    @State private var featuresOffset: CGFloat = -20
    
    var body: some View {
        VStack(spacing: 32) {
            // Animated icon
            ZStack {
                // Outer ring
                Circle()
                    .stroke(step.color.opacity(0.3), lineWidth: 2)
                    .frame(width: 140, height: 140)
                    .scaleEffect(iconScale)
                
                // Glow
                Circle()
                    .fill(step.color.opacity(0.2))
                    .frame(width: 120, height: 120)
                    .blur(radius: 20)
                
                // Icon background
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [step.color.opacity(0.3), step.color.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 110, height: 110)
                    .overlay(
                        Circle()
                            .stroke(step.color.opacity(0.4), lineWidth: 2)
                    )
                
                // Icon
                Image(systemName: step.icon)
                    .font(.system(size: 44))
                    .foregroundColor(step.color)
                    .scaleEffect(iconScale)
            }
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                    iconScale = 1.0
                }
            }
            
            // Text content
            VStack(spacing: 16) {
                Text(step.title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .offset(y: titleOffset)
                    .onAppear {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1)) {
                            titleOffset = 0
                        }
                    }
                
                Text(step.subtitle)
                    .font(.system(size: 17))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 20)
            }
            
            // Feature pills
            VStack(spacing: 12) {
                ForEach(Array(step.features.enumerated()), id: \.element.text) { index, feature in
                    FeaturePill(feature: feature, delay: Double(index) * 0.1)
                }
            }
            .offset(y: featuresOffset)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.2)) {
                    featuresOffset = 0
                }
            }
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Feature Pill

struct FeaturePill: View {
    let feature: Feature
    let delay: Double
    @State private var opacity: Double = 0
    @State private var offset: CGFloat = 10
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: feature.icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
            
            Text(feature.text)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.1))
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
        .opacity(opacity)
        .offset(y: offset)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4).delay(delay)) {
                opacity = 1
                offset = 0
            }
        }
    }
}

// MARK: - Models

struct OnboardingStep {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let features: [Feature]
}

struct Feature {
    let icon: String
    let text: String
}

#Preview {
    EnhancedOnboardingView(currentStep: .constant(0))
        .environmentObject(AppState())
}
