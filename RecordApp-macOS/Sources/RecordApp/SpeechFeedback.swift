import AppKit
import AVFoundation

// Audible confirmation for voice commands so the user knows they were heard.
@preconcurrency class SpeechFeedback: NSObject, AVSpeechSynthesizerDelegate {
    static let shared = SpeechFeedback()

    private let synthesizer = AVSpeechSynthesizer()
    private var onDone: (() -> Void)?

    override private init() {
        super.init()
        synthesizer.delegate = self
    }

    static func ding() {
        NSSound(named: "Tink")?.play()
    }

    func speak(_ text: String, then completion: (() -> Void)? = nil) {
        synthesizer.stopSpeaking(at: .immediate)
        onDone = completion
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.52
        utterance.volume = 0.9
        synthesizer.speak(utterance)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        onDone?()
        onDone = nil
    }
}
