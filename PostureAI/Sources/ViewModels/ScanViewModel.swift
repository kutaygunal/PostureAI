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
    
    var onFrontCaptured: ((URL) -> Void)?
    var onSideCaptured: ((URL) -> Void)?
    
    // MARK: - Init
    init(cameraManager: CameraManager, poseEstimator: PoseEstimator) {
        self.cameraManager = cameraManager
        self.poseEstimator = poseEstimator
        setupFrameProcessing()
    }
    
    // MARK: - Frame Processing
    private func setupFrameProcessing() {
        cameraManager.onFrameCaptured = { [weak self] sampleBuffer in
            Task { @MainActor in
                guard let self = self else { return }
                
                // Always process the frame through pose estimator
                self.poseEstimator.processFrame(sampleBuffer)
                
                // But only handle pose logic when scanning
                if case .scanning = self.state {
                    self.handleScanningFrame()
                }
            }
        }
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
        // Guard: only start from scanning state
        guard case .scanning = state else { return }
        
        // Transition to counting state with value 3
        state = .counting(3)
        countdownValue = 3
        
        // Start async countdown sequence
        countdownTask = Task { @MainActor in
            await self.runCountdownSequence()
        }
    }
    
    private func runCountdownSequence() async {
        // Initial "3"
        AudioManager.shared.playCountdown(number: 3)
        
        // Countdown loop: 3 -> 2 -> 1 -> capture
        for count in [2, 1] {
            // Wait 1 second
            do {
                try await Task.sleep(nanoseconds: 1_000_000_000)
            } catch {
                return // Task cancelled
            }
            
            // Check if we should continue
            guard case .counting = state else { return }
            
            // Update state and UI
            state = .counting(count)
            countdownValue = count
            
            // Play sound
            AudioManager.shared.playCountdown(number: count)
        }
        
        // Wait final second before capture
        do {
            try await Task.sleep(nanoseconds: 1_000_000_000)
        } catch {
            return
        }
        
        // Check state one last time
        guard case .counting = state else { return }
        
        // Transition to capturing
        await performCapture()
    }
    
    // MARK: - Capture
    private func performCapture() async {
        guard case .counting = state else { return }
        
        state = .capturing
        countdownValue = nil
        isCapturing = true
        scanStatus = .captured
        
        // Play sounds
        AudioManager.shared.playReady()
        try? await Task.sleep(nanoseconds: 100_000_000)
        AudioManager.shared.playShutter()
        
        // Take photo and wait for completion
        await withCheckedContinuation { continuation in
            cameraManager.capturePhoto { image in
                continuation.resume()
            }
        }
        
        // Now save the captured image
        await saveCapturedImage()
    }
    
    private func saveCapturedImage() async {
        // Wait a moment for the delegate to set the image
        var attempts = 0
        while cameraManager.capturedImage == nil && attempts < 10 {
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
            attempts += 1
        }
        
        guard let image = cameraManager.capturedImage,
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
                onFrontCaptured?(url)
                
                // Automatically switch to side mode after front capture
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.switchToSideModeWithVoice()
                }
            } else {
                sideCaptured = true
                onSideCaptured?(url)
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
