import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var emulator: EmulatorSession

    var body: some View {
        Form {
            Section("Machine") {
                Picker("Video standard", selection: $emulator.videoStandard) {
                    ForEach(EmulatorSession.VideoStandard.allCases) { standard in
                        Text(standard.rawValue).tag(standard)
                    }
                }
                .pickerStyle(.segmented)

                Toggle("Warp mode", isOn: $emulator.warpMode)
                Toggle("Pause on launch", isOn: $emulator.isPaused)
            }

            Section("Display Chain") {
                VideoFilterPresetPicker()
                VideoFilterSliders()
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 460)
    }
}

#Preview {
    SettingsView()
        .environmentObject(EmulatorSession())
}
