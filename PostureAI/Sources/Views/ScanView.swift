import SwiftUI
import AVFoundation

struct ScanView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var poseEstimator = PoseEstimator()
    @StateObject private var viewModel: ScanViewModel

    init() {
        let cm = CameraManager()
        let pe = PoseEstimator()
        pe.cameraPosition = cm.currentPosition  // Set initial camera position
        _cameraManager = StateObject(wrappedValue: cm)
        _poseEstimator = StateObject(wrappedValue: pe)
        _viewModel = StateObject(wrappedValue: ScanViewModel(cameraManager: cm, poseEstimator: pe))
    }

    var body: some View {
        ZStack {
            // Camera preview - full screen
            if cameraManager.isConfigured {
                CameraPreviewView(cameraManager: cameraManager)
                    .ignoresSafeArea()
            } else {
                Color.black
                    .ignoresSafeArea()
                VStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.2)
                    Text("Starting camera...")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
            }

            // Overlays - using proper VStack layout to avoid overlapping
            if cameraManager.isConfigured {
                VStack(spacing: 0) {
                    // MARK: - Top Controls
                    HStack(spacing: 8) {
                        // Auto Capture Toggle - more space for text
                        HStack(spacing: 8) {
                            Text("Auto Capture")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false) // Force full text display
                            
                            Toggle("", isOn: $viewModel.autoCaptureEnabled)
                                .tint(.green)
                                .labelsHidden()
                                .scaleEffect(0.8)
                                .frame(width: 40)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(.ultraThinMaterial)
                        )
                        
                        Spacer(minLength: 8)
                        
                        // Info button
                        TopControlButton(icon: "info.circle.fill") {
                            // Show info
                        }
                        
                        // Camera rotate
                        TopControlButton(icon: "camera.rotate") {
                            Task {
                                await cameraManager.toggleCamera()
                                // Sync pose estimator with camera position
                                poseEstimator.cameraPosition = cameraManager.currentPosition
                            }
                        }
                        
                        // Close
                        TopControlButton(icon: "xmark.circle.fill") {
                            // Handle back/close
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12) // Moved higher up (was 60)
                    .padding(.bottom, 8)
                    
                    // MARK: - Center Area (Scanning Guide + Skeleton)
                    ZStack {
                        // Silhouette guide
                        SilhouetteGuideView(scanStatus: viewModel.scanStatus)
                        
                        // Skeleton overlay
                        if let pose = poseEstimator.currentPose {
                            SkeletonOverlayView(pose: pose)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    // MARK: - Bottom Panel
                    VStack(spacing: 16) {
                        // Mode selector
                        ModeSelector(
                            currentMode: $viewModel.currentMode,
                            frontCaptured: viewModel.frontCaptured,
                            sideCaptured: viewModel.sideCaptured
                        )
                        
                        // Continue or progress indicator
                        if viewModel.frontCaptured && viewModel.sideCaptured {
                            Button {
                                // Continue to results
                            } label: {
                                HStack(spacing: 8) {
                                    Text("Continue")
                                        .font(.system(size: 17, weight: .semibold))
                                    Image(systemName: "arrow.right")
                                        .font(.system(size: 15, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 54)
                                .background(
                                    LinearGradient(
                                        colors: [.blue, .blue.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                        }
                        
                        // Safe area padding
                        Color.clear
                            .frame(height: 20)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                }
            }

            // Countdown overlay - full screen on top of everything
            if let countdown = viewModel.countdownValue {
                CountdownOverlay(count: countdown)
            }
        }
        .navigationBarHidden(true)
        .task {
            await setupCamera()
        }
        .onAppear {
            setupCallbacks()
        }
    }

    private func setupCallbacks() {
        viewModel.onFrontCaptured = { url, pose in
            appState.capturedFrontImageURL = url
            appState.capturedFrontPose = pose
        }
        viewModel.onSideCaptured = { url, pose in
            appState.capturedSideImageURL = url
            appState.capturedSidePose = pose
        }
    }

    private func setupCamera() async {
        let granted = await cameraManager.checkPermissions()
        if granted {
            await cameraManager.setupAndStartSession()
        }
    }
}

// MARK: - Top Control Button

struct TopControlButton: View {
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                )
        }
    }
}

// MARK: - Mode Selector

struct ModeSelector: View {
    @Binding var currentMode: ScanMode
    let frontCaptured: Bool
    let sideCaptured: Bool

    var body: some View {
        HStack(spacing: 12) {
            ModeButton(
                title: "Front",
                isSelected: currentMode == .front,
                isCompleted: frontCaptured
            ) {
                currentMode = .front
            }

            ModeButton(
                title: "Side",
                isSelected: currentMode == .side,
                isCompleted: sideCaptured
            ) {
                currentMode = .side
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }
}

struct ModeButton: View {
    let title: String
    let isSelected: Bool
    let isCompleted: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.green)
                }
                Text(title)
                    .font(.system(size: 15, weight: isSelected ? .semibold : .medium))
            }
            .foregroundColor(isSelected ? .white : .white.opacity(0.7))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color.blue.opacity(0.9) : Color.clear)
            )
        }
    }
}

// MARK: - Camera Preview

struct CameraPreviewView: UIViewRepresentable {
    @ObservedObject var cameraManager: CameraManager

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black

        if let previewLayer = cameraManager.videoPreviewLayer {
            previewLayer.frame = view.bounds
            view.layer.addSublayer(previewLayer)
        }

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let previewLayer = cameraManager.videoPreviewLayer {
            if previewLayer.superlayer !== uiView.layer {
                uiView.layer.insertSublayer(previewLayer, at: 0)
            }
            previewLayer.frame = uiView.bounds
        }
    }
}

// MARK: - Countdown Overlay

struct CountdownOverlay: View {
    let count: Int
    @State private var scale: CGFloat = 0.3
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            VisualEffectBlur(blurStyle: .systemUltraThinMaterialDark)
                .ignoresSafeArea()

            Text("\(count)")
                .font(.system(size: 200, weight: .thin, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.4), radius: 30)
                .scaleEffect(scale)
                .opacity(opacity)
        }
        .onAppear {
            animateIn()
        }
        .onChange(of: count) { oldValue, newValue in
            // Reset and re-animate when count changes
            scale = 0.3
            opacity = 0
            animateIn()
        }
    }
    
    private func animateIn() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            scale = 1.0
            opacity = 1.0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
            withAnimation(.easeOut(duration: 0.25)) {
                scale = 1.3
                opacity = 0
            }
        }
    }
}

// MARK: - Visual Effect Blur

struct VisualEffectBlur: UIViewRepresentable {
    var blurStyle: UIBlurEffect.Style

    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: blurStyle)
    }
}

#Preview {
    ScanView()
        .environmentObject(AppState())
}
