import Foundation
import SwiftUI
import AVFoundation
import Combine

@MainActor
class ScanViewModel: ObservableObject {
    // MARK: - Published State
    @Published var currentMode: ScanMode = .front
    @Published var scanStatus: ScanStatus = .noDetection
    @Published var autoCaptureEnabled = true
    @Published var isCapturing = false
    @Published var showHeightInput = false
    @Published var frontCaptured = false
    @Published var sideCaptured = false
    @Published var countdownValue: Int?
    
    // MARK: - Dependencies
    let cameraManager: CameraManager
    let poseEstimator: PoseEstimator
    let stabilityTracker = PoseStabilityTracker()
    
    // MARK: - Private State
    private enum State {
        case scanning           // Looking for body, checking stability
        case counting(Int)      // Countdown: 3, 2, 1
        case capturing          // Taking photo
        case coolingDown        // 4s cooldown after capture
        
        var isActive: Bool {
            if case .scanning = self { return false }
            return true
        }
    }
    
    private var state: State = .scanning
    private var countdownTask: Task<Void, Never>?
    private var cooldownTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    
    var onFrontCaptured: ((URL, PoseData) -> Void)?
    var onSideCaptured: ((URL, PoseData) -> Void)?
    
    // MARK: - Init
    init(cameraManager: CameraManager, poseEstimator: PoseEstimator) {
        self.cameraManager = cameraManager
        self.poseEstimator = poseEstimator
        setupFrameProcessing()
    }
    
    // MARK: - Frame Processing
    private func setupFrameProcessing() {
        // Capture reference to avoid @MainActor isolation issues in closure
        let poseEstimator = self.poseEstimator
        
        cameraManager.onFrameCaptured = { sampleBuffer in
            // Vision processing runs on videoOutputQueue (background) — never blocks UI
            poseEstimator.processFrame(sampleBuffer)
        }
        
        // React to pose updates on main thread for scanning logic
        poseEstimator.$currentPose
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                if case .scanning = self.state {
                    self.handleScanningFrame()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Scanning Logic
    private func handleScanningFrame() {
        guard let pose = poseEstimator.currentPose else {
            scanStatus = .noDetection
            stabilityTracker.reset()
            return
        }
        
        // Mode-specific detection
        switch currentMode {
        case .front:
            handleFrontViewDetection(pose: pose)
        case .side:
            handleSideViewDetection(pose: pose)
        }
    }
    
    // MARK: - Front View Detection
    private func handleFrontViewDetection(pose: PoseData) {
        // Calculate body position
        let bodyHeightNorm = PostureAnalyzer.calculateBodyHeightNorm(from: pose)
        let fitStatus = PostureAnalyzer.determineFitStatus(bodyHeightNorm: bodyHeightNorm)
        
        // Update UI status
        scanStatus = fitStatus
        
        // Auto-capture logic
        guard autoCaptureEnabled,
              fitStatus == .detectedHoldStill,
              pose.hasValidJoints else {
            stabilityTracker.reset()
            return
        }
        
        // Feed pose to stability tracker
        stabilityTracker.addPose(pose)
        
        // Start countdown when stable
        if stabilityTracker.isStable {
            beginCountdown()
        }
    }
    
    // MARK: - Side View Detection
    private func handleSideViewDetection(pose: PoseData) {
        // Use side-specific analysis
        let status = PostureAnalyzer.analyzeSideViewPose(from: pose)
        
        // Update UI status
        scanStatus = status
        
        // Only proceed if side profile is good
        // LENIENT: Don't require all joints (arms may be occluded in side view)
        guard status == .sideViewGood,
              autoCaptureEnabled else {
            stabilityTracker.reset()
            return
        }
        
        // LENIENT: For stability tracking, we only need core joints
        // Ignore missing arms/hands - they may be occluded
        guard pose.hasSideViewCoreJoints else {
            stabilityTracker.reset()
            return
        }
        
        // Feed pose to stability tracker
        stabilityTracker.addPose(pose)
        
        // Start countdown when stable
        if stabilityTracker.isStable {
            beginCountdown()
        }
    }
    
    // MARK: - Countdown Sequence
    private func beginCountdown() {
        guard case .scanning = state else { return }
        
        // Set UI state first, then audio - ensures animation starts before sound
        state = .counting(3)
        countdownValue = 3
        
        // Small delay ensures view has appeared before audio plays
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            AudioManager.shared.playCountdown(number: 3)
        }
        
        countdownTask = Task { @MainActor in
            // 3 is already showing; wait then show 2, then 1
            for number in [2, 1] {
                do {
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                } catch { return }
                guard case .counting = self.state else { return }
                
                self.state = .counting(number)
                self.countdownValue = number
                AudioManager.shared.playCountdown(number: number)
            }
            
            // Wait final second then capture
            do {
                try await Task.sleep(nanoseconds: 1_000_000_000)
            } catch { return }
            guard case .counting = self.state else { return }
            
            self.countdownValue = nil
            await self.performCapture()
        }
    }
    
    // MARK: - Capture
    private func performCapture() async {
        guard case .counting = state else { return }
        
        // Store the current pose BEFORE capture (it will still be valid)
        let capturedPose = poseEstimator.currentPose
        
        state = .capturing
        countdownValue = nil
        isCapturing = true
        scanStatus = .captured
        
        // Play sounds
        AudioManager.shared.playReady()
        try? await Task.sleep(nanoseconds: 100_000_000)
        AudioManager.shared.playShutter()
        
        // Take photo and wait for result
        let capturedImage: UIImage? = await withCheckedContinuation { continuation in
            cameraManager.capturePhoto { image in
                continuation.resume(returning: image)
            }
        }
        
        // Save the captured image with pose data
        await saveCapturedImage(image: capturedImage, capturedPose: capturedPose)
    }
    
    private func saveCapturedImage(image: UIImage?, capturedPose: PoseData?) async {
        guard let image,
              let imageData = image.jpegData(compressionQuality: 0.8) else {
            isCapturing = false
            enterCooldown()
            return
        }
        
        let timestamp = Date().timeIntervalSince1970
        let filename = "\(currentMode.rawValue.lowercased().replacingOccurrences(of: " ", with: "_"))_\(Int(timestamp)).jpg"
        
        if let url = PersistenceManager.shared.saveImage(imageData, filename: filename) {
            AudioManager.shared.playSuccess()
            
            if currentMode == .front {
                frontCaptured = true
                onFrontCaptured?(url, capturedPose ?? PoseData())
                
                // Automatically switch to side mode after front capture
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.switchToSideModeWithVoice()
                }
            } else {
                sideCaptured = true
                onSideCaptured?(url, capturedPose ?? PoseData())
            }
        }
        
        isCapturing = false
        enterCooldown()
    }
    
    /// Switch to side mode with Turkish voice announcement
    private func switchToSideModeWithVoice() {
        cancelAllTasks()
        
        // Speak Turkish announcement
        AudioManager.shared.announceSideViewMode()
        
        // Switch mode after a brief delay to let voice start
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.currentMode = .side
            self.state = .scanning
            self.stabilityTracker.reset()
            self.scanStatus = .noDetection
        }
    }
    
    // MARK: - Cooldown
    private func enterCooldown() {
        state = .coolingDown
        stabilityTracker.reset()
        scanStatus = .noDetection
        
        cooldownTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: 4_000_000_000) // 4 seconds
                
                // Only return to scanning if still in cooldown (not interrupted)
                if case .coolingDown = self.state {
                    self.state = .scanning
                }
            } catch {
                // Task cancelled, stay in current state or handle in reset
            }
        }
    }
    
    // MARK: - Public Methods
    func toggleMode() {
        cancelAllTasks()
        currentMode = (currentMode == .front) ? .side : .front
        state = .scanning
        stabilityTracker.reset()
        scanStatus = .noDetection
    }
    
    func reset() {
        cancelAllTasks()
        frontCaptured = false
        sideCaptured = false
        currentMode = .front
        state = .scanning
        stabilityTracker.reset()
        scanStatus = .noDetection
    }
    
    private func cancelAllTasks() {
        countdownTask?.cancel()
        countdownTask = nil
        cooldownTask?.cancel()
        cooldownTask = nil
        countdownValue = nil
        isCapturing = false
    }
}
