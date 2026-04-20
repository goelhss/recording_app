import AppKit

class SettingsWindowController: NSWindowController {
    static let shared = SettingsWindowController()

    private init() {
        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 160),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "RecordApp Settings"
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)
        buildUI()
    }

    required init?(coder: NSCoder) { nil }

    private func buildUI() {
        guard let content = window?.contentView else { return }

        let modeLabel = NSTextField(labelWithString: "Recording mode:")
        modeLabel.frame = NSRect(x: 20, y: 118, width: 130, height: 20)

        let modePopup = NSPopUpButton(frame: NSRect(x: 155, y: 114, width: 210, height: 26))
        modePopup.addItems(withTitles: RecordingMode.allCases.map { $0.label })
        modePopup.selectItem(at: RecordingMode.allCases.firstIndex(of: NoteStore.shared.recordingMode) ?? 0)
        modePopup.target = self
        modePopup.action = #selector(modeChanged(_:))

        let storageLabel = NSTextField(labelWithString: "Save to:")
        storageLabel.frame = NSRect(x: 20, y: 82, width: 130, height: 20)

        let storagePopup = NSPopUpButton(frame: NSRect(x: 155, y: 78, width: 120, height: 26))
        storagePopup.addItems(withTitles: ["Local folder", "Google Drive"])
        storagePopup.selectItem(at: NoteStore.shared.destination == .local ? 0 : 1)
        storagePopup.target = self
        storagePopup.action = #selector(storageChanged(_:))

        let logCheck = NSButton(checkboxWithTitle: "Enable debug logging", target: self, action: #selector(logToggled(_:)))
        logCheck.frame = NSRect(x: 20, y: 46, width: 280, height: 20)
        logCheck.state = Logger.shared.isEnabled ? .on : .off

        let openFolder = NSButton(title: "Open Recordings Folder", target: self, action: #selector(openFolder))
        openFolder.frame = NSRect(x: 20, y: 12, width: 200, height: 24)
        openFolder.bezelStyle = .inline

        content.addSubview(modeLabel)
        content.addSubview(modePopup)
        content.addSubview(storageLabel)
        content.addSubview(storagePopup)
        content.addSubview(logCheck)
        content.addSubview(openFolder)
    }

    func show() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func modeChanged(_ sender: NSPopUpButton) {
        NoteStore.shared.recordingMode = RecordingMode.allCases[sender.indexOfSelectedItem]
    }

    @objc private func storageChanged(_ sender: NSPopUpButton) {
        NoteStore.shared.destination = sender.indexOfSelectedItem == 0 ? .local : .googleDrive
    }

    @objc private func logToggled(_ sender: NSButton) {
        Logger.shared.isEnabled = sender.state == .on
    }

    @objc private func openFolder() {
        NoteStore.shared.openNotesFolder()
    }
}
