import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            MachineSettingsPane()
                .tabItem {
                    Label("Machine", systemImage: "cpu")
                }

            SoundSettingsPane()
                .tabItem {
                    Label("Sound", systemImage: "speaker.wave.2")
                }

            DriveSettingsPane()
                .tabItem {
                    Label("Drives", systemImage: "externaldrive")
                }

            DisplaySettingsPane()
                .tabItem {
                    Label("Display", systemImage: "display")
                }
        }
        .frame(width: 560, height: 500)
    }
}

private struct MachineSettingsPane: View {
    @EnvironmentObject private var emulator: EmulatorSession

    var body: some View {
        SettingsPane {
            Section("Machine") {
                Picker("Video standard", selection: $emulator.videoStandard) {
                    ForEach(EmulatorSession.VideoStandard.allCases) { standard in
                        Text(standard.rawValue).tag(standard)
                    }
                }
                .pickerStyle(.segmented)

                Picker("Speed", selection: $emulator.emulationSpeed) {
                    ForEach(EmulatorSession.EmulationSpeed.allCases) { speed in
                        Text(speed.title).tag(speed)
                    }
                }

                Toggle("Paused", isOn: $emulator.isPaused)
            }
        }
    }
}

private struct SoundSettingsPane: View {
    @EnvironmentObject private var emulator: EmulatorSession

    var body: some View {
        SettingsPane {
            Section("Playback") {
                LabeledContent("Output") {
                    Label("CoreAudio", systemImage: "checkmark.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                }

                Toggle("Sound", isOn: $emulator.soundEnabled)

                LabeledContent("Volume") {
                    HStack(spacing: 10) {
                        Slider(value: volumeBinding, in: 0...100)
                            .disabled(!emulator.soundEnabled)

                        Text("\(emulator.soundVolume)%")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 44, alignment: .trailing)
                    }
                }
            }

            Section("SID") {
                Picker("Model", selection: $emulator.sidModel) {
                    ForEach(EmulatorSession.SIDModel.allCases) { model in
                        Text(model.title).tag(model)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private var volumeBinding: Binding<Double> {
        Binding {
            Double(emulator.soundVolume)
        } set: { value in
            emulator.soundVolume = Int(value.rounded())
        }
    }
}

private struct DisplaySettingsPane: View {
    @EnvironmentObject private var emulator: EmulatorSession

    var body: some View {
        SettingsPane {
            Section("Window") {
                Picker("Display size", selection: $emulator.displayMode) {
                    ForEach(EmulatorSession.DisplayMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
            }

            Section("Display Chain") {
                VideoFilterPresetPicker()
                VideoFilterSliders()
            }
        }
    }
}

private struct DriveSettingsPane: View {
    @EnvironmentObject private var emulator: EmulatorSession

    var body: some View {
        SettingsPane {
            ForEach(emulator.driveConfigurations.indices, id: \.self) { index in
                DriveSettingsSection(drive: $emulator.driveConfigurations[index])
            }
        }
    }
}

private struct DriveSettingsSection: View {
    @Binding var drive: DriveConfiguration

    var body: some View {
        Section("Drive \(drive.unit)") {
            Toggle("Attached", isOn: $drive.isAttached)

            Picker("Type", selection: $drive.driveType) {
                ForEach(DriveType.allCases) { type in
                    Text(type.title).tag(type)
                }
            }
            .disabled(!drive.isAttached)

            Toggle("Drive sounds", isOn: $drive.soundEnabled)
                .disabled(!drive.isAttached)

            HStack(spacing: 12) {
                Text("Sound volume")

                Slider(value: volumeBinding, in: 0...4000)
                    .disabled(!drive.isAttached || !drive.soundEnabled)

                Text("\(drive.soundVolume)")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 44, alignment: .trailing)
            }
        }
    }

    private var volumeBinding: Binding<Double> {
        Binding {
            Double(drive.soundVolume)
        } set: { value in
            drive.soundVolume = Int(value.rounded())
        }
    }
}

private struct SettingsPane<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        Form {
            content
        }
        .formStyle(.grouped)
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
    }
}

#Preview {
    SettingsView()
        .environmentObject(EmulatorSession())
}
