import SwiftUI
import AVFoundation

// MARK: - Enhanced Scan View with Modern UI/UX

struct EnhancedScanView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var poseEstimator = PoseEstimator()
    @StateObject private var viewModel: ScanViewModel
    
    // Animation states
    @State private var showSuccessAnimation = false
    @State private var buttonScale: CGFloat = 1.0
    @State private var topControlsOffset: CGFloat = 0
    @State private var bottomPanelOffset: CGFloat = 0
    @State private var skeletonOpacity: Double = 0
    @State private var modeSelectorScale: CGFloat = 0.9
    
    // Navigation state
    @State private var showResults = false
    @State private var showHeightInput = false
    
    init() {
        let cm = CameraManager()
        let pe = PoseEstimator()
        pe.cameraPosition = cm.currentPosition
        _cameraManager = StateObject(wrappedValue: cm)
        _poseEstimator = StateObject(wrappedValue: pe)
        _viewModel = StateObject(wrappedValue: ScanViewModel(cameraManager: cm, poseEstimator: pe))
    }
    
    var body: some View {
        ZStack {
            // MARK: - Background layers
            Color.black.ignoresSafeArea()
            
            // MARK: - Camera preview
            if cameraManager.isConfigured {
                CameraPreviewView(cameraManager: cameraManager)
                    .ignoresSafeArea()
                    .opacity(showSuccessAnimation ? 0.3 : 1)
                    .animation(.easeInOut(duration: 0.3), value: showSuccessAnimation)
            } else {
                CameraLoadingView()
            }
            
            // MARK: - Scanning animations
            if cameraManager.isConfigured && !showSuccessAnimation {
                ScanningAnimationView(
                    isActive: viewModel.scanStatus.isGood && !viewModel.isCapturing,
                    status: viewModel.scanStatus
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }
            
            // MARK: - Main content
            if cameraManager.isConfigured {
                VStack(spacing: 0) {
                    // Top controls
                    EnhancedTopControls(
                        viewModel: viewModel,
                        cameraManager: cameraManager,
                        poseEstimator: poseEstimator
                    )
                    .offset(y: topControlsOffset)
                    
                    Spacer()
                    
                    // Center guide area
                    ZStack {
                        // Silhouette guide with enhanced animation
                        EnhancedSilhouetteGuideView(scanStatus: viewModel.scanStatus)
                            .scaleEffect(statusScale)
                            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isBodyDetected)
                        
                        // Skeleton overlay with fade
                        if let pose = poseEstimator.currentPose {
                            EnhancedSkeletonOverlayView(pose: pose)
                                .opacity(skeletonOpacity)
                                .onAppear {
                                    withAnimation(.easeOut(duration: 0.5)) {
                                        skeletonOpacity = 1
                                    }
                                }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    // Bottom panel
                    EnhancedBottomPanel(viewModel: viewModel, showHeightInput: $showHeightInput)
                        .offset(y: bottomPanelOffset)
                }
            }
            
            // MARK: - Countdown overlay
            if let countdown = viewModel.countdownValue {
                EnhancedCountdownOverlay(count: countdown)
                    .id("countdown-\(countdown)") // Force recreation for each number
            }
            
            // MARK: - Success celebration
            if showSuccessAnimation {
                SuccessCelebrationView {
                    withAnimation(.easeOut(duration: 0.3)) {
                        showSuccessAnimation = false
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .navigationDestination(isPresented: $showResults) {
            EnhancedReportView()
                .environmentObject(appState)
        }
        .sheet(isPresented: $showHeightInput) {
            HeightInputSheet {
                showHeightInput = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showResults = true
                }
            }
            .environmentObject(appState)
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
            .presentationBackground(Color(red: 0.08, green: 0.08, blue: 0.1))
            .interactiveDismissDisabled()
        }
        .task {
            await setupCamera()
        }
        .onAppear {
            setupCallbacks()
            animateEntrance()
        }
        .onDisappear {
            HapticManager.shared.stopFeedback()
        }
    }
    
    // MARK: - Computed Properties
    
    private var isBodyDetected: Bool {
        viewModel.scanStatus == .detectedHoldStill || viewModel.scanStatus == .sideViewGood
    }
    
    private var statusScale: CGFloat {
        if viewModel.scanStatus.isGood {
            return 1.0
        } else if viewModel.scanStatus == .noDetection {
            return 1.0
        } else {
            return 0.95
        }
    }
    
    // MARK: - Setup & Callbacks
    
    private func animateEntrance() {
        // Animate top controls
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
            topControlsOffset = 0
        }
        
        // Animate bottom panel
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2)) {
            bottomPanelOffset = 0
            modeSelectorScale = 1.0
        }
    }
    
    private func setupCallbacks() {
        viewModel.onFrontCaptured = { url, pose in
            appState.capturedFrontImageURL = url
            appState.capturedFrontPose = pose
            triggerSuccessAnimation()
        }
        
        viewModel.onSideCaptured = { url, pose in
            appState.capturedSideImageURL = url
            appState.capturedSidePose = pose
            triggerSuccessAnimation()
        }
    }
    
    private func triggerSuccessAnimation() {
        HapticManager.shared.successFeedback()
        showSuccessAnimation = true
    }
    
    private func setupCamera() async {
        let granted = await cameraManager.checkPermissions()
        if granted {
            await cameraManager.setupAndStartSession()
        }
    }
}

// MARK: - Camera Loading View

struct CameraLoadingView: View {
    @State private var isPulsing = false
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 100, height: 100)
                        .scaleEffect(isPulsing ? 1.2 : 1.0)
                    
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                }
                
                Text("Starting camera...")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }
}

// MARK: - Enhanced Top Controls

struct EnhancedTopControls: View {
    @ObservedObject var viewModel: ScanViewModel
    @ObservedObject var cameraManager: CameraManager
    @ObservedObject var poseEstimator: PoseEstimator
    @State private var isExpanded = true
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                // Auto capture toggle with glassmorphism
                EnhancedToggle(
                    isOn: $viewModel.autoCaptureEnabled,
                    title: "Auto",
                    icon: "camera.fill"
                )
                
                Spacer()
                
                // Camera rotate button
                EnhancedIconButton(icon: "camera.rotate.fill") {
                    Task {
                        await cameraManager.toggleCamera()
                        poseEstimator.cameraPosition = cameraManager.currentPosition
                    }
                }
                
                // Close button
                EnhancedIconButton(icon: "xmark") {
                    // Handle close
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
        }
        .background(.ultraThinMaterial.opacity(0.5))
    }
}

// MARK: - Enhanced Toggle

struct EnhancedToggle: View {
    @Binding var isOn: Bool
    let title: String
    let icon: String
    @State private var scale: CGFloat = 1.0
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isOn.toggle()
                scale = 0.95
            }
            HapticManager.shared.lightFeedback()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                scale = 1.0
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: isOn ? icon : "camera")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isOn ? .white : .white.opacity(0.7))
                
                Text(isOn ? "Auto ON" : "Auto OFF")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(isOn ? Color.blue.opacity(0.9) : Color.white.opacity(0.15))
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .scaleEffect(scale)
    }
}

// MARK: - Enhanced Icon Button

struct EnhancedIconButton: View {
    let icon: String
    let action: () -> Void
    @State private var scale: CGFloat = 1.0
    
    var body: some View {
        Button(action: {
            HapticManager.shared.lightFeedback()
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                scale = 0.85
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                scale = 1.0
            }
            action()
        }) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
        }
        .scaleEffect(scale)
    }
}

// MARK: - Enhanced Silhouette Guide

struct EnhancedSilhouetteGuideView: View {
    let scanStatus: ScanStatus
    @State private var pulseScale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.5
    
    var body: some View {
        GeometryReader { geometry in
            let frameWidth = geometry.size.width - 40
            let frameHeight = min(geometry.size.height * 0.92, frameWidth / 0.55)
            
            ZStack {
                // Dynamic glow background
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color.clear)
                    .frame(width: frameWidth + 16, height: frameHeight + 16)
                    .background(
                        RoundedRectangle(cornerRadius: 28)
                            .fill(statusColor.opacity(glowOpacity))
                            .blur(radius: isDetecting ? 30 : 15)
                            .scaleEffect(pulseScale)
                    )
                
                // Main frame with animated border
                RoundedRectangle(cornerRadius: 24)
                    .stroke(
                        isDetecting ? statusColor : Color.white.opacity(0.8),
                        style: StrokeStyle(
                            lineWidth: isDetecting ? 4 : 3,
                            lineCap: .round,
                            lineJoin: .round,
                            dash: isDetecting ? [] : [8, 4]
                        )
                    )
                    .frame(width: frameWidth, height: frameHeight)
                    .shadow(color: statusColor.opacity(0.6), radius: isDetecting ? 20 : 8)
                    
                // Corner brackets
                CornerBrackets(width: frameWidth, height: frameHeight, color: statusColor)
                
                // Status badge
                EnhancedStatusBadge(status: scanStatus)
                    .position(x: geometry.size.width / 2, y: 35)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .onAppear {
            if isDetecting {
                startPulseAnimation()
            }
        }
        .onChange(of: isDetecting) { _, new in
            if new {
                startPulseAnimation()
            }
        }
    }
    
    private var isDetecting: Bool {
        scanStatus.isGood
    }
    
    private func startPulseAnimation() {
        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
            pulseScale = 1.05
            glowOpacity = 0.8
        }
    }
    
    private var statusColor: Color {
        switch scanStatus {
        case .detectedHoldStill, .sideViewGood:
            return .green
        case .moveCloser, .moveBack:
            return .orange
        case .turnToSide, .turnMoreToSide:
            return .yellow
        case .captured:
            return .blue
        default:
            return .white
        }
    }
}

// MARK: - Corner Brackets

struct CornerBrackets: View {
    let width: CGFloat
    let height: CGFloat
    let color: Color
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Top left
            CornerBracket()
                .stroke(color, lineWidth: 3)
                .frame(width: 30, height: 30)
                .position(x: 15, y: 15)
            
            // Top right
            CornerBracket()
                .stroke(color, lineWidth: 3)
                .rotationEffect(.degrees(90))
                .frame(width: 30, height: 30)
                .position(x: width - 15, y: 15)
            
            // Bottom right
            CornerBracket()
                .stroke(color, lineWidth: 3)
                .rotationEffect(.degrees(180))
                .frame(width: 30, height: 30)
                .position(x: width - 15, y: height - 15)
            
            // Bottom left
            CornerBracket()
                .stroke(color, lineWidth: 3)
                .rotationEffect(.degrees(270))
                .frame(width: 30, height: 30)
                .position(x: 15, y: height - 15)
        }
        .frame(width: width, height: height)
    }
}

struct CornerBracket: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let length: CGFloat = min(rect.width, rect.height) * 0.7
        path.move(to: CGPoint(x: 0, y: length))
        path.addLine(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: length, y: 0))
        return path
    }
}

// MARK: - Enhanced Status Badge

struct EnhancedStatusBadge: View {
    let status: ScanStatus
    @State private var scale: CGFloat = 1.0
    
    var body: some View {
        HStack(spacing: 8) {
            if status.isGood {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .transition(.scale)
            }
            
            Text(status.displayText)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.6))
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
        )
        .scaleEffect(scale)
        .onChange(of: status.displayText) { _ in
            withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                scale = 1.1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                scale = 1.0
            }
        }
    }
}

// MARK: - Enhanced Bottom Panel

struct EnhancedBottomPanel: View {
    @ObservedObject var viewModel: ScanViewModel
    @Binding var showHeightInput: Bool
    @State private var continueButtonScale: CGFloat = 1.0
    
    var body: some View {
        VStack(spacing: 16) {
            // Mode selector with glassmorphism
            EnhancedModeSelector(
                currentMode: $viewModel.currentMode,
                frontCaptured: viewModel.frontCaptured,
                sideCaptured: viewModel.sideCaptured
            )
            
            // Continue button or capture status
            if viewModel.frontCaptured && viewModel.sideCaptured {
                Button(action: {
                    HapticManager.shared.successFeedback()
                    showHeightInput = true
                }) {
                    HStack(spacing: 8) {
                        Text("View Results")
                            .font(.system(size: 17, weight: .semibold))
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 18))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        LinearGradient(
                            colors: [.blue, .blue.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: .blue.opacity(0.4), radius: 12, x: 0, y: 4)
                }
                .scaleEffect(continueButtonScale)
                .onAppear {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                        continueButtonScale = 1.0
                    }
                }
            } else {
                // Show scanning status instead of duplicate progress
                ScanningStatusView(
                    status: viewModel.scanStatus,
                    currentMode: viewModel.currentMode
                )
            }
            
            Color.clear.frame(height: 20)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
        .background(
            LinearGradient(
                colors: [
                    Color.black.opacity(0),
                    Color.black.opacity(0.3),
                    Color.black.opacity(0.7)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(.container, edges: .bottom)
        )
    }
}

// MARK: - Scanning Status View (Replaces duplicate CaptureProgressView)

struct ScanningStatusView: View {
    let status: ScanStatus
    let currentMode: ScanMode
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: currentMode == .front ? "person.fill" : "arrow.left.arrow.right")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.7))
            
            Text(statusMessage)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    private var statusMessage: String {
        switch status {
        case .noDetection:
            return "Position body in frame"
        case .moveCloser:
            return "Move closer"
        case .moveBack:
            return "Move back"
        case .detectedHoldStill:
            return "Hold still..."
        case .captured:
            return "Captured!"
        case .turnToSide, .turnMoreToSide:
            return "Turn to side view"
        case .sideViewGood:
            return "Hold still..."
        }
    }
}

// MARK: - Enhanced Mode Selector

struct EnhancedModeSelector: View {
    @Binding var currentMode: ScanMode
    let frontCaptured: Bool
    let sideCaptured: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            EnhancedModeButton(
                title: "Front",
                icon: "person.fill",
                isSelected: currentMode == .front,
                isCompleted: frontCaptured
            ) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    currentMode = .front
                }
            }
            
            EnhancedModeButton(
                title: "Side",
                icon: "arrow.left.arrow.right",
                isSelected: currentMode == .side,
                isCompleted: sideCaptured
            ) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    currentMode = .side
                }
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

struct EnhancedModeButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let isCompleted: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 14))
                        .transition(.scale)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 14))
                }
                
                Text(title)
                    .font(.system(size: 15, weight: isSelected ? .semibold : .medium))
            }
            .foregroundColor(isSelected ? .white : .white.opacity(0.7))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? Color.blue.opacity(0.9) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(isSelected ? Color.blue.opacity(0.5) : Color.clear, lineWidth: 2)
                    )
            )
        }
    }
}

// MARK: - Enhanced Countdown Overlay

struct EnhancedCountdownOverlay: View {
    let count: Int
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0
    @State private var rotation: Double = -30
    
    var body: some View {
        ZStack {
            // Dark backdrop with blur
            VisualEffectBlurView(blurStyle: .systemUltraThinMaterialDark)
                .ignoresSafeArea()
            
            // Countdown number
            Text("\(count)")
                .font(.system(size: 220, weight: .thin, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, .cyan.opacity(0.8)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: .cyan.opacity(0.5), radius: 30, x: 0, y: 0)
                .shadow(color: .cyan.opacity(0.3), radius: 60, x: 0, y: 0)
                .scaleEffect(scale)
                .opacity(opacity)
                .rotationEffect(.degrees(rotation))
            
            // Ring animation
            CountdownRing(count: count)
        }
        .onAppear {
            animateIn()
        }
    }
    
    private func animateIn() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            scale = 1.0
            opacity = 1.0
            rotation = 0
        }
        
        HapticManager.shared.countdownFeedback()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
            withAnimation(.easeOut(duration: 0.25)) {
                scale = 1.3
                opacity = 0
                rotation = 30
            }
        }
    }
}

struct CountdownRing: View {
    let count: Int
    @State private var progress: CGFloat = 0
    
    var body: some View {
        Circle()
            .trim(from: 0, to: progress)
            .stroke(
                Color.cyan.opacity(0.5),
                style: StrokeStyle(lineWidth: 4, lineCap: .round)
            )
            .frame(width: 280, height: 280)
            .rotationEffect(.degrees(-90))
            .onAppear {
                withAnimation(.linear(duration: 1.0)) {
                    progress = 1
                }
            }
            .id("ring-\(count)") // Force recreation for each number
    }
}

// MARK: - Visual Effect Blur

struct VisualEffectBlurView: UIViewRepresentable {
    var blurStyle: UIBlurEffect.Style
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: blurStyle)
    }
}

#Preview {
    EnhancedScanView()
        .environmentObject(AppState())
}
