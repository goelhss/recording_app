import Foundation

enum VoiceCommand {
    case startRecording
    case stopRecording
    case convertToText
    case appendToLast
    case changeToLocal
    case changeToGoogleDrive
    case playbackLatest
    case playbackToday
    case deleteLatest
    case whereAreSaved
    case howManyToday
}

struct VoiceCommandParser {
    // Lenient matching — handles minor speech recognition errors.
    // Order matters: more specific patterns before broad ones.
    static func parse(_ text: String) -> VoiceCommand? {
        // Strip punctuation so "Hey, Recorder" matches the same as "Hey Recorder"
        let t = text.lowercased()
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: "!", with: "")
        let hasWake = t.contains("hey recorder") || t.contains("hey record")
                   || t.contains("he recorder")  || t.contains("he record")
                   || t.contains("recorder")
                   || t.contains("jeanie") || t.contains("jeannie") || t.contains("genie")
                   || t.contains("ginny") || t.contains("jenny") || t.contains("jinny")
                   || t.contains("rrr")
        guard hasWake else { return nil }

        if t.contains("stop") || t.contains("close")                         { return .stopRecording }
        if t.contains("convert")                                              { return .convertToText }
        if t.contains("start") || t.contains("chart") || t.contains("guard") { return .startRecording }
        if t.contains("append")                           { return .appendToLast }
        if t.contains("local storage") || t.contains("local mode") { return .changeToLocal }
        if t.contains("google drive") || t.contains("google dr")   { return .changeToGoogleDrive }
        if t.contains("play") && t.contains("today")     { return .playbackToday }
        if t.contains("play") && t.contains("latest")    { return .playbackLatest }
        if t.contains("delete")                           { return .deleteLatest }
        if t.contains("where") && t.contains("saved")    { return .whereAreSaved }
        if t.contains("how many")                         { return .howManyToday }

        return nil
    }
}
