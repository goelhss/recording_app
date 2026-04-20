import Foundation
import WhisperKit

class WhisperTranscriber {
    static let shared = WhisperTranscriber()
    private var whisper: WhisperKit?

    private init() {}

    // Lazily loads model on first call (~150 MB download once, then cached)
    func transcribe(audioURL: URL) async throws -> String {
        if whisper == nil {
            whisper = try await WhisperKit(model: "base.en")
        }
        let results = try await whisper!.transcribe(audioPath: audioURL.path)
        return results.compactMap { $0.text }.joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
