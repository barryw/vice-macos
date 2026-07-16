import SwiftUI

struct VideoFilterPresetPicker: View {
    @EnvironmentObject private var emulator: EmulatorSession
    let labelTitle: String?
    let labelSystemImage: String?

    init(labelTitle: String? = nil, labelSystemImage: String? = nil) {
        self.labelTitle = labelTitle
        self.labelSystemImage = labelSystemImage
    }

    var body: some View {
        Picker(selection: presetBinding) {
            ForEach(VideoFilterPreset.allCases) { preset in
                Label(preset.title, systemImage: preset.systemImage)
                    .tag(preset)
            }
        } label: {
            Label(labelTitle ?? emulator.filterSettings.preset.toolbarTitle,
                  systemImage: labelSystemImage ?? emulator.filterSettings.preset.systemImage)
        }
        .pickerStyle(.menu)
    }

    private var presetBinding: Binding<VideoFilterPreset> {
        Binding {
            emulator.filterSettings.preset
        } set: { preset in
            emulator.applyFilterPreset(preset)
        }
    }
}

struct VideoFilterSliders: View {
    @EnvironmentObject private var emulator: EmulatorSession

    var body: some View {
        VStack(spacing: 10) {
            FilterSlider("Scanlines", value: $emulator.filterSettings.scanlineIntensity, range: 0...0.75)
            FilterSlider("Phosphor mask", value: $emulator.filterSettings.phosphorMaskIntensity, range: 0...0.65)
            FilterSlider("Glass curve", value: $emulator.filterSettings.barrelDistortion, range: 0...0.12)
            FilterSlider("Edge falloff", value: $emulator.filterSettings.vignette, range: 0...0.5)
            FilterSlider("Halation", value: $emulator.filterSettings.halation, range: 0...0.45)
            FilterSlider("Persistence", value: $emulator.filterSettings.phosphorPersistence, range: 0...1.0)
            FilterSlider("Saturation", value: $emulator.filterSettings.saturation, range: 0.65...1.45)
            FilterSlider("Warmth", value: $emulator.filterSettings.warmth, range: -0.25...0.25)
        }
    }
}

struct FilterSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>

    init(_ title: String, value: Binding<Double>, range: ClosedRange<Double>) {
        self.title = title
        self._value = value
        self.range = range
    }

    var body: some View {
        SettingsSliderControl(value: $value,
                              range: range,
                              valueTitle: value.formatted(.number.precision(.fractionLength(2))),
                              leadingTitle: title)
    }
}
