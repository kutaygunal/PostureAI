import AVFoundation
import AudioToolbox

@MainActor
class AudioManager {
    static let shared = AudioManager()
    
    // Sound IDs for countdown: 3 (low), 2 (med), 1 (high)
    // These are system sounds with ascending pitch
    private let countdownLow: SystemSoundID = 1113
    private let countdownMed: SystemSoundID = 1114
    private let countdownHigh: SystemSoundID = 1115
    
    private let readySound: SystemSoundID = 1117
    private let shutterSound: SystemSoundID = 1108
    private let secondaryShutter: SystemSoundID = 1105
    private let successSound: SystemSoundID = 1118
    
    // Turkish speech synthesizer
    private let synthesizer = AVSpeechSynthesizer()
    
    private init() {
        // Eagerly initialize audio session to avoid first-use delay
        prewarmAudioSession()
    }
    
    /// Pre-warm the audio system to eliminate initialization delays during countdown
    private func prewarmAudioSession() {
        // Pre-warm speech synthesizer with a silent utterance
        // This ensures the synthesizer is ready when needed
        let warmupUtterance = AVSpeechUtterance(string: " ")
        warmupUtterance.volume = 0.001
        warmupUtterance.rate = 0.5
        synthesizer.speak(warmupUtterance)
        synthesizer.stopSpeaking(at: .immediate)
        
        // Ensure audio session is configured for playback
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try audioSession.setActive(true)
        } catch {
            print("Audio session prewarm failed: \(error)")
        }
    }
    
    /// Explicitly prewarm audio - call this early in app lifecycle for best performance
    func prewarm() {
        // Already warmed in init, but this method allows explicit early initialization
        // if called from App init before first use
    }
    
    /// Play countdown sound for specific number (3, 2, or 1)
    /// Uses ascending pitch: 3=low, 2=medium, 1=high
    func playCountdown(number: Int) {
        let soundID: SystemSoundID
        switch number {
        case 3: soundID = countdownLow
        case 2: soundID = countdownMed
        case 1: soundID = countdownHigh
        default: soundID = countdownMed
        }
        AudioServicesPlaySystemSound(soundID)
    }
    
    /// Play "ready" sound just before shutter (after 1)
    func playReady() {
        AudioServicesPlaySystemSound(readySound)
    }
    
    /// Play camera shutter sound
    func playShutter() {
        AudioServicesPlaySystemSound(shutterSound)
        // Secondary sound for emphasis
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            AudioServicesPlaySystemSound(self.secondaryShutter)
        }
    }
    
    /// Play success sound after photo is saved
    func playSuccess() {
        AudioServicesPlaySystemSound(successSound)
    }
    
    /// Speak text in Turkish
    func speakTurkish(text: String) {
        // Stop any current speech
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "tr-TR")
        utterance.rate = 0.5  // Slower rate for clarity
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        
        synthesizer.speak(utterance)
    }
    
    /// Announce transition to side view in Turkish
    func announceSideViewMode() {
        speakTurkish(text: "Ön görüntü kaydedildi. Yan pozisyona geçin ve profilinizi gösterin.")
    }
}
