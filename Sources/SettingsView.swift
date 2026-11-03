import SwiftUI

struct SettingsView: View {
    @AppStorage(Defaults.repeatCount) private var repeatCount = 1
    @AppStorage(Defaults.speed) private var speed = 1.0

    var body: some View {
        Form {
            Section {
                LabeledContent("Repeat") {
                    HStack(spacing: 6) {
                        TextField("Repeat", value: $repeatCount, format: .number)
                            .labelsHidden()
                            .multilineTextAlignment(.trailing)
                            .frame(width: 64)
                        Stepper("Repeat", value: $repeatCount, in: 1...9999)
                            .labelsHidden()
                        Text(repeatCount == 1 ? "time" : "times")
                            .foregroundStyle(.secondary)
                    }
                }

                Picker("Speed", selection: $speed) {
                    ForEach(Defaults.speedOptions, id: \.self) { option in
                        Text(speedLabel(option)).tag(option)
                    }
                }
                .pickerStyle(.menu)
            } header: {
                Text("Playback")
            } footer: {
                Text("Press Esc at any time to stop playback.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 380)
        .fixedSize(horizontal: false, vertical: true)
        .onChange(of: repeatCount) { _, newValue in
            let clamped = min(9999, max(1, newValue))
            if clamped != newValue { repeatCount = clamped }
        }
    }

    private func speedLabel(_ option: Double) -> String {
        switch option {
        case 0.5: return "\(speedText(option))  Half speed"
        case 1: return "\(speedText(option))  Normal"
        case 2: return "\(speedText(option))  Double speed"
        default: return speedText(option)
        }
    }
}
