import SwiftUI

/// The floating panel: Record / Stop / Play plus a summary of the current settings.
struct ControlView: View {
    @ObservedObject var engine: MacroEngine
    @ObservedObject var permissions: Permissions
    var openSettings: () -> Void

    @AppStorage(Defaults.repeatCount) private var repeatCount = 1
    @AppStorage(Defaults.speed) private var speed = 1.0

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            statusLine

            HStack(spacing: 10) {
                ActionButton(title: "Record", symbol: "record.circle.fill", tint: .red,
                             enabled: engine.state == .idle) { engine.startRecording() }
                ActionButton(title: "Stop", symbol: "stop.fill", tint: .primary,
                             enabled: engine.state != .idle) { engine.stop() }
                ActionButton(title: "Play", symbol: "play.fill", tint: .green,
                             enabled: engine.state == .idle && engine.hasRecording) { engine.play() }
            }

            Text(hint)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let notice = engine.notice {
                Text(notice)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !permissions.allGranted {
                PermissionsBox(permissions: permissions)
            }

            Divider()

            HStack(spacing: 14) {
                Label("Repeat \(repeatCount)×", systemImage: "repeat")
                    .help("Times the recording plays")
                Label("Speed \(speedText(speed))", systemImage: "speedometer")
                    .help("Playback speed")
                Spacer()
                Button(action: openSettings) {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.borderless)
                .help("Settings")
            }
            .font(.callout)
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(width: 300)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var statusLine: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 9, height: 9)
            Text(statusText)
                .font(.headline)
            Spacer()
            if engine.state != .idle {
                Text(clockText(engine.clock))
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var statusColor: Color {
        switch engine.state {
        case .idle: return .secondary.opacity(0.5)
        case .recording: return .red
        case .playing: return .green
        }
    }

    private var statusText: String {
        switch engine.state {
        case .idle: return engine.hasRecording ? "Ready to play" : "Ready to record"
        case .recording: return "Recording…"
        case .playing: return engine.rounds > 1 ? "Playing \(engine.round) of \(engine.rounds)" : "Playing"
        }
    }

    private var hint: String {
        switch engine.state {
        case .recording:
            return "Do your clicks and typing, then press Stop."
        case .playing:
            return "Press Esc to stop."
        case .idle where engine.hasRecording:
            return "\(engine.eventCount) events · \(String(format: "%.1f", engine.duration)) s per run"
        case .idle:
            return "Press Record, do your clicks and typing, then press Stop."
        }
    }

    private func clockText(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        return String(format: "%d:%04.1f", minutes, seconds - Double(minutes * 60))
    }
}

func speedText(_ speed: Double) -> String {
    let number = speed.truncatingRemainder(dividingBy: 1) == 0
        ? String(format: "%.0f", speed)
        : String(format: "%g", speed)
    return "\(number)×"
}

private struct ActionButton: View {
    let title: String
    let symbol: String
    let tint: Color
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 22, weight: .semibold))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .foregroundStyle(enabled ? tint : Color.secondary.opacity(0.45))
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.06)))
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(PressStyle())
        .disabled(!enabled)
    }
}

private struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

private struct PermissionsBox: View {
    @ObservedObject var permissions: Permissions

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("AutoClicker needs permission")
                .font(.callout.weight(.semibold))
            if !permissions.accessibility {
                row("Accessibility", detail: "to replay clicks and keys",
                    open: Permissions.openAccessibilitySettings)
            }
            if !permissions.inputMonitoring {
                row("Input Monitoring", detail: "to record keys",
                    open: Permissions.openInputMonitoringSettings)
            }
            HStack {
                Text("Turned them on? Relaunch to apply.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Relaunch", action: Permissions.relaunch)
                    .controlSize(.small)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.orange.opacity(0.12)))
    }

    private func row(_ title: String, detail: String, open: @escaping () -> Void) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.callout)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Open", action: open)
                .controlSize(.small)
        }
    }
}
