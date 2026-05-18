import SwiftUI

struct VideoFilterPresetPicker: View {
    @EnvironmentObject private var emulator: EmulatorSession

    var body: some View {
        Picker("Display", selection: presetBinding) {
            ForEach(VideoFilterPreset.allCases) { preset in
                Text(preset.rawValue).tag(preset)
            }
        }
        .pickerStyle(.segmented)
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
            FilterSlider("Saturation", value: $emulator.filterSettings.saturation, range: 0.65...1.45)
            FilterSlider("Warmth", value: $emulator.filterSettings.warmth, range: -0.25...0.25)
        }
    }
}

struct VideoFilterToolbarPanel: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Display")
                .font(.headline)

            VideoFilterPresetPicker()

            Divider()

            VideoFilterSliders()
        }
        .padding(16)
        .frame(width: 360)
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
        HStack(spacing: 12) {
            Text(title)
                .frame(width: 112, alignment: .leading)

            Slider(value: $value, in: range)

            Text(value, format: .number.precision(.fractionLength(2)))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 42, alignment: .trailing)
        }
    }
}
