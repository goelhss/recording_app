import AppKit
import UserNotifications

class StatusBarController {
    private var statusItem: NSStatusItem
    private var menu: NSMenu
    private let audio = AudioManager.shared
    private let store = NoteStore.shared
    private let tts = SpeechFeedback.shared

    private var statusLabel: NSMenuItem!
    private var startItem: NSMenuItem!
    private var stopItem: NSMenuItem!
    private var activeNoteURL: URL?

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        menu = NSMenu()
        setupButton()
        setupMenu()

        audio.onCommand = { [weak self] cmd in self?.handle(cmd) }
        audio.onStateChange = { [weak self] in self?.refreshMenu() }
        audio.onHeard = { [weak self] text in
            guard let self, !self.audio.isRecording else { return }
            self.statusLabel.title = "Heard: \(text)"
        }
        audio.onScanResult = { [weak self] msg in
            guard let self, !self.audio.isRecording else { return }
            self.statusLabel.title = msg
        }
        audio.onWhisperComplete = { [weak self] url in
            guard let self else { return }
            let name = url.lastPathComponent
            self.statusLabel.title = "Transcribed: \(name)"
            self.notify("Transcription ready", body: name)
        }

        requestNotificationPermission()
    }

    // MARK: - Setup

    private func setupButton() {
        guard let button = statusItem.button else { return }
        button.title = "🐱"
    }

    private func setupMenu() {
        statusLabel = NSMenuItem(title: "Listening for commands…", action: nil, keyEquivalent: "")
        statusLabel.isEnabled = false
        menu.addItem(statusLabel)

        menu.addItem(NSMenuItem.separator())

        startItem = makeItem("Start Recording", action: #selector(startRecording), key: "r")
        stopItem  = makeItem("Stop Recording",  action: #selector(stopRecording),  key: ".")
        stopItem.isEnabled = false

        menu.addItem(startItem)
        menu.addItem(stopItem)
        menu.addItem(NSMenuItem.separator())

        menu.addItem(makeItem("Convert Audio Files to Text", action: #selector(convertAudio), key: ""))
        menu.addItem(makeItem("Play Back Latest Note",    action: #selector(playbackLatest),   key: ""))
        menu.addItem(makeItem("Open Notes Folder",        action: #selector(openFolder),        key: "o"))
        menu.addItem(makeItem("Settings…",                action: #selector(openSettings),      key: ","))
        menu.addItem(makeItem("Delete Latest Note",       action: #selector(deleteLatest),      key: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(makeItem("Quit RecordApp", action: #selector(quitApp), key: "q"))

        statusItem.menu = menu
    }

    private func makeItem(_ title: String, action: Selector, key: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    // MARK: - Voice command handler

    func handle(_ command: VoiceCommand) {
        SpeechFeedback.ding()
        statusLabel.title = "Command: \(command)"
        switch command {
        case .startRecording:
            guard !audio.isRecording else { return }
            tts.speak("Starting recording") { [weak self] in self?.beginRecording() }

        case .stopRecording:
            guard audio.isRecording else { return }
            tts.speak("Stopping") { [weak self] in self?.endRecording() }

        case .convertToText:
            tts.speak("Converting latest audio") { [weak self] in self?.convertLatestAudio() }

        case .appendToLast:
            if audio.isRecording {
                tts.speak("Stopping current recording") { [weak self] in self?.endRecording() }
            } else {
                tts.speak("Starting recording") { [weak self] in self?.beginRecording()
                }
            }

        case .changeToLocal:
            store.setDestination(.local)
            tts.speak("Switched to local storage")
            notify("Storage mode", body: "Notes will save to ~/Documents/RecordApp/")

        case .changeToGoogleDrive:
            store.setDestination(.googleDrive)
            tts.speak("Switched to Google Drive")
            notify("Storage mode", body: "Notes will sync to Google Drive")

        case .playbackLatest:
            if let text = store.latestNoteText() {
                tts.speak(text)
            } else {
                tts.speak("No notes found")
            }

        case .playbackToday:
            let notes = store.todaysNotes()
            if notes.isEmpty {
                tts.speak("No notes today")
            } else {
                tts.speak(notes.joined(separator: ". Next note. "))
            }

        case .deleteLatest:
            guard let name = store.latestNoteName() else {
                tts.speak("No notes to delete")
                return
            }
            confirmDelete(name: name)

        case .whereAreSaved:
            let dest = store.destination == .local ? "local storage" : "Google Drive"
            tts.speak("Your notes are saved to \(dest)")

        case .howManyToday:
            let count = store.todaysNoteCount()
            tts.speak("You have \(count) note\(count == 1 ? "" : "s") today")
        }
    }

    // MARK: - Recording actions

    private func beginRecording() {
        activeNoteURL = store.newNoteURL()
        audio.startRecording(to: activeNoteURL!, mode: store.recordingMode)
        refreshMenu()
        let modeLabel: String
        switch store.recordingMode {
        case .whisper:     modeLabel = "Whisper"
        case .cloudSTT:    modeLabel = "Cloud STT"
        case .onDeviceSTT: modeLabel = "On-device STT"
        case .audioOnly:   modeLabel = "Audio only"
        }
        notify("Recording started (\(modeLabel))", body: activeNoteURL!.lastPathComponent)
    }

    private func endRecording() {
        let url = audio.stopRecording()
        activeNoteURL = nil
        refreshMenu()
        if let url {
            notify("Saved", body: url.lastPathComponent)
        }
    }

    private func convertLatestAudio() {
        let files = store.unconvertedAudioFiles()
        guard !files.isEmpty else {
            tts.speak("No unconverted audio files found")
            return
        }
        tts.speak("Converting \(files.count) file\(files.count == 1 ? "" : "s"), please wait")
        statusLabel.title = "Converting 0 of \(files.count)…"
        convertNext(files: files, index: 0, total: files.count, succeeded: 0)
    }

    private func convertNext(files: [URL], index: Int, total: Int, succeeded: Int) {
        guard index < files.count else {
            let msg = "Done. \(succeeded) of \(total) converted."
            tts.speak(msg)
            notify("Transcription complete", body: msg)
            refreshMenu()
            return
        }
        let url = files[index]
        statusLabel.title = "Converting \(index + 1) of \(total): \(url.lastPathComponent)"
        Logger.shared.log("CONVERTING \(index + 1)/\(total): \(url.lastPathComponent)")

        audio.transcribeAudioFile(url) { [weak self] text in
            DispatchQueue.main.async {
                guard let self else { return }
                var newSucceeded = succeeded
                if let text, !text.isEmpty {
                    let txtURL = url.deletingPathExtension().appendingPathExtension("txt")
                    let content = "Converted: \(Date())\nSource: \(url.lastPathComponent)\n\n\(text)\n"
                    try? content.write(to: txtURL, atomically: true, encoding: .utf8)
                    newSucceeded += 1
                    Logger.shared.log("CONVERTED OK: \(txtURL.lastPathComponent)")
                } else {
                    Logger.shared.log("CONVERSION FAILED: \(url.lastPathComponent)")
                }
                self.convertNext(files: files, index: index + 1, total: total, succeeded: newSucceeded)
            }
        }
    }

    func saveAndQuit() {
        if audio.isRecording { endRecording() }
    }

    @objc private func startRecording() { handle(.startRecording) }
    @objc private func stopRecording()  { handle(.stopRecording) }
    @objc private func convertAudio()   { handle(.convertToText) }
    @objc private func openSettings()   { SettingsWindowController.shared.show() }
    @objc private func quitApp()        { NSApplication.shared.terminate(nil) }

    @objc private func playbackLatest() { handle(.playbackLatest) }
    @objc private func openFolder()     { store.openNotesFolder() }

    @objc private func deleteLatest() {
        guard let name = store.latestNoteName() else { return }
        confirmDelete(name: name)
    }

    private func confirmDelete(name: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Delete note?"
            alert.informativeText = name
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Delete")
            alert.addButton(withTitle: "Cancel")
            if alert.runModal() == .alertFirstButtonReturn {
                self.store.deleteLatestNote()
                self.tts.speak("Note deleted")
            }
        }
    }

    // MARK: - Menu state

    private func refreshMenu() {
        DispatchQueue.main.async {
            let recording = self.audio.isRecording
            self.startItem.isEnabled = !recording
            self.stopItem.isEnabled  = recording
            self.statusLabel.title   = recording ? "● Recording…" : "Listening for commands…"
            if let button = self.statusItem.button {
                button.title = recording ? "🙀" : "🐱"
            }
        }
    }

    // MARK: - Notifications

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func notify(_ title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body  = body
        let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req)
    }
}
