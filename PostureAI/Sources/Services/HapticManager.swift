import UIKit

// MARK: - Haptic Feedback Manager

class HapticManager {
    static let shared = HapticManager()
    
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let notification = UINotificationFeedbackGenerator()
    private let selection = UISelectionFeedbackGenerator()
    
    // Continuous feedback for scanning
    private var continuousFeedback: UISelectionFeedbackGenerator?
    private var isProvidingContinuousFeedback = false
    
    private init() {
        // Prepare generators
        lightImpact.prepare()
        mediumImpact.prepare()
        heavyImpact.prepare()
        notification.prepare()
        selection.prepare()
    }
    
    // MARK: - Basic Feedback
    
    func lightFeedback() {
        lightImpact.prepare()
        lightImpact.impactOccurred()
    }
    
    func mediumFeedback() {
        mediumImpact.prepare()
        mediumImpact.impactOccurred()
    }
    
    func heavyFeedback() {
        heavyImpact.prepare()
        heavyImpact.impactOccurred()
    }
    
    func selectionFeedback() {
        selection.prepare()
        selection.selectionChanged()
    }
    
    // MARK: - Notification Feedback
    
    func successFeedback() {
        notification.prepare()
        notification.notificationOccurred(.success)
    }
    
    func errorFeedback() {
        notification.prepare()
        notification.notificationOccurred(.error)
    }
    
    func warningFeedback() {
        notification.prepare()
        notification.notificationOccurred(.warning)
    }
    
    // MARK: - Specific Scan Feedback
    
    func countdownFeedback() {
        mediumImpact.prepare()
        mediumImpact.impactOccurred()
    }
    
    func captureFeedback() {
        // Sequence of feedbacks for capture
        heavyImpact.prepare()
        heavyImpact.impactOccurred()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.successFeedback()
        }
    }
    
    func bodyDetectedFeedback() {
        // Subtle pulse when body detected
        lightImpact.prepare()
        lightImpact.impactOccurred(intensity: 0.5)
    }
    
    func beginContinuousFeedback() {
        guard !isProvidingContinuousFeedback else { return }
        isProvidingContinuousFeedback = true
        
        continuousFeedback = UISelectionFeedbackGenerator()
        continuousFeedback?.prepare()
    }
    
    func stopFeedback() {
        isProvidingContinuousFeedback = false
        continuousFeedback = nil
    }
    
    // MARK: - Mode Switch Feedback
    
    func modeSwitchFeedback() {
        selectionFeedback()
    }
    
    // MARK: - Button Feedback
    
    func buttonTapFeedback() {
        lightFeedback()
    }
}
