import Foundation
import AppKit

enum StorageDestination {
    case local
    case googleDrive
}

enum RecordingMode: String, CaseIterable {
    case whisper     = "whisper"
    case cloudSTT    = "cloudSTT"
    case onDeviceSTT = "onDeviceSTT"
    case audioOnly   = "audioOnly"

    var label: String {
        switch self {
        case .whisper:     return "Whisper (offline, high quality — default)"
        case .cloudSTT:    return "Cloud STT (best quality, needs internet)"
        case .onDeviceSTT: return "On-device STT (offline, lower quality)"
        case .audioOnly:   return "Audio only (say \"Genie, convert\" to transcribe)"
        }
    }
}

class NoteStore {
    static let shared = NoteStore()

    private let notesDirectory: URL
    private let prefsKey = "storageDestination"

    var destination: StorageDestination {
        get { UserDefaults.standard.string(forKey: prefsKey) == "googleDrive" ? .googleDrive : .local }
        set { UserDefaults.standard.set(newValue == .googleDrive ? "googleDrive" : "local", forKey: prefsKey) }
    }

    var recordingMode: RecordingMode {
        get { RecordingMode(rawValue: UserDefaults.standard.string(forKey: "recordingMode") ?? "") ?? .whisper }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "recordingMode") }
    }

    private init() {
        // App is at build/mac/RecordApp.app — go up 3 levels to reach record_app/
        let projectRoot = Bundle.main.bundleURL
            .deletingLastPathComponent() // build/mac/
            .deletingLastPathComponent() // build/
            .deletingLastPathComponent() // record_app/
        notesDirectory = projectRoot.appendingPathComponent("recordings")
        try? FileManager.default.createDirectory(at: notesDirectory, withIntermediateDirectories: true)
    }

    func setDestination(_ dest: StorageDestination) {
        destination = dest
    }

    // MARK: - Save

    func newNoteURL() -> URL {
        try? FileManager.default.createDirectory(at: notesDirectory, withIntermediateDirectories: true)
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return notesDirectory.appendingPathComponent("\(fmt.string(from: Date())).txt")
    }

    func saveTranscript(_ text: String, to url: URL) {
        let content = "Recorded: \(Date())\n\n\(text)\n"
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            Logger.shared.log("SAVE ERROR: \(error)")
        }
    }

    func appendToLastNote(_ text: String) {
        guard let latest = latestNoteURL() else { return }
        let appended = "\n--- Appended \(Date()) ---\n\(text)\n"
        if let handle = try? FileHandle(forWritingTo: latest) {
            handle.seekToEndOfFile()
            handle.write(appended.data(using: .utf8) ?? Data())
            handle.closeFile()
        }
    }

    // MARK: - Read

    func latestNoteURL() -> URL? { noteFiles().last }

    func latestAudioFile() -> URL? {
        unconvertedAudioFiles().last
    }

    // All .caf files that don't yet have a matching .txt transcript
    func unconvertedAudioFiles() -> [URL] {
        let fm = FileManager.default
        guard let all = try? fm.contentsOfDirectory(at: notesDirectory, includingPropertiesForKeys: nil) else { return [] }
        let cafFiles = all.filter { $0.pathExtension == "caf" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        return cafFiles.filter { caf in
            let txt = caf.deletingPathExtension().appendingPathExtension("txt")
            return !fm.fileExists(atPath: txt.path)
        }
    }

    func latestNoteName() -> String? {
        latestNoteURL()?.lastPathComponent
    }

    func latestNoteText() -> String? {
        guard let url = latestNoteURL() else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    func todaysNotes() -> [String] {
        let cal = Calendar.current
        return noteFiles()
            .filter { cal.isDateInToday(fileDate($0)) }
            .compactMap { try? String(contentsOf: $0, encoding: .utf8) }
    }

    func todaysNoteCount() -> Int {
        let cal = Calendar.current
        return noteFiles().filter { cal.isDateInToday(fileDate($0)) }.count
    }

    // MARK: - Delete

    func deleteLatestNote() {
        guard let url = latestNoteURL() else { return }
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Filesystem

    func openNotesFolder() {
        NSWorkspace.shared.open(notesDirectory)
    }

    private func noteFiles() -> [URL] {
        let fm = FileManager.default
        return (try? fm.contentsOfDirectory(at: notesDirectory, includingPropertiesForKeys: [.creationDateKey]))
            .map { $0.filter { $0.pathExtension == "txt" }.sorted { $0.lastPathComponent < $1.lastPathComponent } }
            ?? []
    }


    private func fileDate(_ url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
    }
}
