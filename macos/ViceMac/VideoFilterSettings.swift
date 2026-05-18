import Foundation

struct VideoFilterSettings: Equatable {
    var preset: VideoFilterPreset = .commodore1702
    var scanlineIntensity = 0.34
    var phosphorMaskIntensity = 0.18
    var barrelDistortion = 0.035
    var vignette = 0.22
    var halation = 0.16
    var saturation = 1.08
    var warmth = 0.04

    static func defaults(for preset: VideoFilterPreset) -> VideoFilterSettings {
        switch preset {
        case .clean:
            return VideoFilterSettings(
                preset: preset,
                scanlineIntensity: 0.0,
                phosphorMaskIntensity: 0.0,
                barrelDistortion: 0.0,
                vignette: 0.0,
                halation: 0.0,
                saturation: 1.0,
                warmth: 0.0
            )

        case .commodore1702:
            return VideoFilterSettings(
                preset: preset,
                scanlineIntensity: 0.34,
                phosphorMaskIntensity: 0.18,
                barrelDistortion: 0.035,
                vignette: 0.22,
                halation: 0.16,
                saturation: 1.08,
                warmth: 0.04
            )

        case .pvm:
            return VideoFilterSettings(
                preset: preset,
                scanlineIntensity: 0.42,
                phosphorMaskIntensity: 0.26,
                barrelDistortion: 0.012,
                vignette: 0.12,
                halation: 0.08,
                saturation: 1.12,
                warmth: -0.02
            )

        case .rf:
            return VideoFilterSettings(
                preset: preset,
                scanlineIntensity: 0.24,
                phosphorMaskIntensity: 0.08,
                barrelDistortion: 0.055,
                vignette: 0.28,
                halation: 0.24,
                saturation: 0.96,
                warmth: 0.08
            )
        }
    }
}

enum VideoFilterPreset: String, CaseIterable, Identifiable {
    case clean = "Clean"
    case commodore1702 = "1702"
    case pvm = "PVM"
    case rf = "RF"

    var id: String { rawValue }
}
