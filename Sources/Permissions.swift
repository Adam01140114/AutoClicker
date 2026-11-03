import AppKit
import ApplicationServices

/// Tracks the two privacy permissions AutoClicker needs:
/// Accessibility (to replay clicks and keys) and Input Monitoring (to record keys).
final class Permissions: ObservableObject {
    @Published private(set) var accessibility = AXIsProcessTrusted()
    @Published private(set) var inputMonitoring = CGPreflightListenEventAccess()

    var allGranted: Bool { accessibility && inputMonitoring }

    private var timer: Timer?

    /// Shows the system prompts for whatever is missing, then watches for the user to flip the switches.
    func requestMissing() {
        if !accessibility {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
        }
        if !inputMonitoring {
            CGRequestListenEventAccess()
        }
        guard !allGranted else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    private func refresh() {
        let a = AXIsProcessTrusted()
        let i = CGPreflightListenEventAccess()
        if a != accessibility { accessibility = a }
        if i != inputMonitoring { inputMonitoring = i }
        if allGranted {
            timer?.invalidate()
            timer = nil
        }
    }

    static func openAccessibilitySettings() {
        open("Privacy_Accessibility")
    }

    static func openInputMonitoringSettings() {
        open("Privacy_ListenEvent")
    }

    private static func open(_ pane: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") {
            NSWorkspace.shared.open(url)
        }
    }

    /// macOS often only applies a newly granted permission after the app restarts.
    static func relaunch() {
        let path = Bundle.main.bundlePath
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", "sleep 0.5; /usr/bin/open \"$0\"", path]
        try? task.run()
        NSApp.terminate(nil)
    }
}
