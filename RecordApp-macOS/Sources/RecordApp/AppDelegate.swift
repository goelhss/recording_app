import AppKit
import Speech

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?

    func applicationWillTerminate(_ notification: Notification) {
        statusBarController?.saveAndQuit()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        requestSpeechPermission {
            do {
                try AudioManager.shared.startEngine()
                self.statusBarController = StatusBarController()
            } catch {
                self.showFatalError("Could not start microphone: \(error.localizedDescription)")
            }
        }
    }

    private func requestSpeechPermission(then completion: @escaping () -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    completion()
                default:
                    let alert = NSAlert()
                    alert.messageText = "Speech Recognition Required"
                    alert.informativeText = "Open System Settings › Privacy & Security › Speech Recognition and enable RecordApp, then relaunch."
                    alert.addButton(withTitle: "Open Settings")
                    alert.addButton(withTitle: "Quit")
                    if alert.runModal() == .alertFirstButtonReturn {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_SpeechRecognition")!)
                    }
                    NSApp.terminate(nil)
                }
            }
        }
    }

    private func showFatalError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "RecordApp Error"
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.runModal()
        NSApp.terminate(nil)
    }
}
