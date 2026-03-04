import SwiftUI
import AVFoundation

struct ScanView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var cameraManager: CameraManager
    @StateObject private var poseEstimator: PoseEstimator
    @StateObject private var viewModel: ScanViewModel

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
            CountdownOverlayView(number: $viewModel.countdownValue)
        }
        .navigationBarHidden(true)
        .task {
            setupCallbacks()
            await setupCamera()
        }
        .onDisappear {
            cameraManager.stopSession()
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

class CameraPreviewUIView: UIView {
    var previewLayer: AVCaptureVideoPreviewLayer? {
        didSet {
            oldValue?.removeFromSuperlayer()
            if let previewLayer {
                layer.insertSublayer(previewLayer, at: 0)
                previewLayer.frame = bounds
            }
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }
}

struct CameraPreviewView: UIViewRepresentable {
    @ObservedObject var cameraManager: CameraManager

    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.backgroundColor = .black
        view.previewLayer = cameraManager.videoPreviewLayer
        return view
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        if uiView.previewLayer !== cameraManager.videoPreviewLayer {
            uiView.previewLayer = cameraManager.videoPreviewLayer
        }
    }
}

// MARK: - Countdown Overlay

/// Robust countdown overlay with synchronized animation and audio.
/// The overlay appears when number is not nil, with smooth ring animation.
private struct CountdownOverlayView: View {
    @Binding var number: Int?
    @State private var isAnimating = false
    @State private var viewId = UUID()
    
    private let totalDuration: Double = 3.0
    private let ringSize: CGFloat = 180

    var body: some View {
        Group {
            if number != nil {
                ZStack {
                    // Background blur
                    VisualEffectBlur(blurStyle: .systemUltraThinMaterialDark)
                        .ignoresSafeArea()

                    ZStack {
                        // Background ring (dim)
                        Circle()
                            .stroke(Color.white.opacity(0.15), lineWidth: 6)
                            .frame(width: ringSize, height: ringSize)

                        // Progress ring — animates from full to empty over 3 seconds
                        Circle()
                            .trim(from: 0, to: isAnimating ? 0.0 : 1.0)
                            .stroke(
                                Color.white,
                                style: StrokeStyle(lineWidth: 6, lineCap: .round)
                            )
                            .frame(width: ringSize, height: ringSize)
                            .rotationEffect(.degrees(-90))
                            .animation(
                                .linear(duration: totalDuration),
                                value: isAnimating
                            )

                        // Number display
                        if let num = number {
                            Text("\(num)")
                                .font(.system(size: 100, weight: .thin, design: .rounded))
                                .foregroundStyle(.white)
                                .contentTransition(.numericText(countsDown: true))
                                .transition(.scale.combined(with: .opacity))
                                .animation(.easeInOut(duration: 0.15), value: num)
                        }
                    }
                }
                .transition(.opacity)
                .id(viewId)
            }
        }
        .onAppear {
            setupAnimationTrigger()
        }
        .onChange(of: number) { oldValue, newValue in
            // Detect countdown restart (nil -> 3)
            if oldValue == nil, let val = newValue, val == 3 {
                // Reset for new countdown
                viewId = UUID()
                isAnimating = false
                setupAnimationTrigger()
            }
            // Detect countdown end (any number -> nil)
            else if newValue == nil {
                isAnimating = false
            }
        }
    }
    
    private func setupAnimationTrigger() {
        guard number != nil else { return }
        // Small delay ensures view is rendered before animation starts
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
            isAnimating = true
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
