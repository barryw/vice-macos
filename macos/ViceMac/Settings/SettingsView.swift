import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var emulator: EmulatorSession

    var body: some View {
        Form {
            Picker("Video standard", selection: $emulator.videoStandard) {
                ForEach(EmulatorSession.VideoStandard.allCases) { standard in
                    Text(standard.rawValue).tag(standard)
                }
            }
            .pickerStyle(.segmented)

            Toggle("Warp mode", isOn: $emulator.warpMode)
            Toggle("Pause on launch", isOn: $emulator.isPaused)
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 420)
    }
}

#Preview {
    SettingsView()
        .environmentObject(EmulatorSession())
}
