import AVFoundation
import Speech

class AudioManager: NSObject {
    static let shared = AudioManager()

    private let audioEngine = AVAudioEngine()
    private let commandRecognizer  = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let transcribeRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))

    // Command listener
    private var commandRequest: SFSpeechAudioBufferRecognitionRequest?
    private var commandTask: SFSpeechRecognitionTask?
    private var commandDetectedInSession = false
    private var commandCooldown = false
    private var isRestartingCommand = false

    // STT capture (cloud / on-device modes)
    private var isCapturingTranscript = false
    private var currentSessionBest = ""
    private var activeNoteURL: URL?

    // Audio-only / whisper recording
    private var audioFile: AVAudioFile?
    private var activeMode: RecordingMode = .whisper

    private(set) var isRecording = false

    var onCommand: ((VoiceCommand) -> Void)?
    var onStateChange: (() -> Void)?
    var onHeard: ((String) -> Void)?
    var onScanResult: ((String) -> Void)?
    var onWhisperComplete: ((URL) -> Void)?

    // MARK: - Engine

    func startEngine() throws {
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.commandRequest?.append(buffer)
            if let f = self?.audioFile { try? f.write(from: buffer) }
        }
        audioEngine.prepare()
        try audioEngine.start()
        Logger.shared.log("ENGINE STARTED")
        beginCommandListening()
    }

    // MARK: - Command listening

    private func beginCommandListening() {
        commandRequest = SFSpeechAudioBufferRecognitionRequest()
        commandRequest?.requiresOnDeviceRecognition = false
        commandRequest?.shouldReportPartialResults = true
        commandDetectedInSession = false
        currentSessionBest = ""

        commandTask = commandRecognizer?.recognitionTask(with: commandRequest!) { [weak self] result, error in
            guard let self else { return }
            if let result {
                let text = result.bestTranscription.formattedString
                Logger.shared.log("HEARD: \(text)")
                DispatchQueue.main.async { self.onHeard?(text) }
                self.scanForCommand(in: text)

                if self.isCapturingTranscript {
                    self.currentSessionBest = text
                    if result.isFinal { self.flushSessionToFile() }
                }
            }
            if let error {
                Logger.shared.log("CMD ERROR: \(error.localizedDescription)")
                if self.isCapturingTranscript { self.flushSessionToFile() }
                guard !self.isRestartingCommand else { return }
                self.isRestartingCommand = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    self.isRestartingCommand = false
                    self.beginCommandListening()
                }
            }
        }
    }

    private func restartCommandListening() {
        commandRequest?.endAudio()
        commandTask?.cancel()
        commandRequest = nil
        commandTask = nil
        commandDetectedInSession = false
        beginCommandListening()
    }

    private func scanForCommand(in text: String) {
        if commandCooldown || commandDetectedInSession { return }
        let lower = text.lowercased()
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: ".", with: "")
        let hasWake = lower.contains("hey recorder") || lower.contains("hey record")
                   || lower.contains("he recorder")  || lower.contains("he record")
                   || lower.contains("recorder")
                   || lower.contains("jeanie") || lower.contains("jeannie") || lower.contains("genie")
                   || lower.contains("rrr")
        DispatchQueue.main.async {
            self.onScanResult?(hasWake ? "WAKE: \(lower.prefix(60))" : "no wake: \(lower.prefix(60))")
        }
        guard hasWake, let cmd = VoiceCommandParser.parse(text) else { return }
        Logger.shared.log("CMD FIRED: \(cmd)")
        commandDetectedInSession = true
        commandCooldown = true
        DispatchQueue.main.async { self.onCommand?(cmd) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.commandCooldown = false
            self.restartCommandListening()
        }
    }

    // MARK: - Recording

    func startRecording(to url: URL, mode: RecordingMode) {
        guard !isRecording else { return }
        activeNoteURL = url
        currentSessionBest = ""
        activeMode = mode

        switch mode {
        case .whisper:
            let audioURL = url.deletingPathExtension().appendingPathExtension("caf")
            let format = audioEngine.inputNode.outputFormat(forBus: 0)
            audioFile = try? AVAudioFile(forWriting: audioURL, settings: format.settings)
            activeNoteURL = audioURL
            Logger.shared.log("RECORDING STARTED — whisper → \(audioURL.lastPathComponent)")

        case .cloudSTT:
            commandRequest?.requiresOnDeviceRecognition = false
            let header = "Started: \(Date())\n\n"
            try? header.write(to: url, atomically: true, encoding: .utf8)
            isCapturingTranscript = true
            Logger.shared.log("RECORDING STARTED — cloud STT → \(url.lastPathComponent)")

        case .onDeviceSTT:
            commandRequest?.requiresOnDeviceRecognition = true
            let header = "Started: \(Date())\n\n"
            try? header.write(to: url, atomically: true, encoding: .utf8)
            isCapturingTranscript = true
            Logger.shared.log("RECORDING STARTED — on-device STT → \(url.lastPathComponent)")

        case .audioOnly:
            let audioURL = url.deletingPathExtension().appendingPathExtension("caf")
            let format = audioEngine.inputNode.outputFormat(forBus: 0)
            audioFile = try? AVAudioFile(forWriting: audioURL, settings: format.settings)
            activeNoteURL = audioURL
            Logger.shared.log("RECORDING STARTED — audio only → \(audioURL.lastPathComponent)")
        }

        isRecording = true
        DispatchQueue.main.async { self.onStateChange?() }
    }

    func stopRecording() -> URL? {
        guard isRecording else { return nil }
        isCapturingTranscript = false
        flushSessionToFile()
        let cafURL = activeMode == .whisper ? activeNoteURL : nil
        audioFile = nil       // closes + flushes .caf
        isRecording = false
        let url = activeNoteURL
        activeNoteURL = nil
        Logger.shared.log("RECORDING STOPPED")
        DispatchQueue.main.async { self.onStateChange?() }
        if let cafURL {
            autoTranscribeWithWhisper(cafURL)
        }
        return url
    }

    private func autoTranscribeWithWhisper(_ cafURL: URL) {
        Logger.shared.log("WHISPER: queuing transcription for \(cafURL.lastPathComponent)")
        Task {
            do {
                let text = try await WhisperTranscriber.shared.transcribe(audioURL: cafURL)
                let txtURL = cafURL.deletingPathExtension().appendingPathExtension("txt")
                let content = "Recorded: \(Date())\nSource: \(cafURL.lastPathComponent)\n\n\(text)\n"
                try content.write(to: txtURL, atomically: true, encoding: .utf8)
                Logger.shared.log("WHISPER: saved \(txtURL.lastPathComponent)")
                DispatchQueue.main.async { self.onWhisperComplete?(txtURL) }
            } catch {
                Logger.shared.log("WHISPER ERROR: \(error.localizedDescription)")
                DispatchQueue.main.async { self.onWhisperComplete?(cafURL) }
            }
        }
    }

    // MARK: - Audio-only → text conversion

    func transcribeAudioFile(_ url: URL, completion: @escaping (String?) -> Void) {
        Logger.shared.log("TRANSCRIBING: \(url.lastPathComponent)")
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.requiresOnDeviceRecognition = false
        request.shouldReportPartialResults = false
        transcribeRecognizer?.recognitionTask(with: request) { result, error in
            if let result, result.isFinal {
                let text = result.bestTranscription.formattedString
                Logger.shared.log("TRANSCRIPTION DONE: \(text.prefix(80))")
                completion(text)
            } else if let error {
                Logger.shared.log("TRANSCRIPTION ERROR: \(error.localizedDescription)")
                completion(nil)
            }
        }
    }

    // MARK: - Helpers

    private func flushSessionToFile() {
        let text = currentSessionBest.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let url = activeNoteURL else {
            currentSessionBest = ""
            return
        }
        Logger.shared.log("FLUSH: \(text.prefix(80))")
        appendToNoteFile(text + "\n")
        currentSessionBest = ""
    }

    private func appendToNoteFile(_ text: String) {
        guard let url = activeNoteURL, let data = text.data(using: .utf8) else { return }
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(data)
            handle.closeFile()
        }
    }
}
