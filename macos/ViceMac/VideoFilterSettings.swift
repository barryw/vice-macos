import Foundation

struct VideoFilterSettings: Codable, Equatable {
    var preset: VideoFilterPreset = .commodore1702
    var scanlineIntensity = 0.34
    var phosphorMaskIntensity = 0.18
    var barrelDistortion = 0.035
    var vignette = 0.22
    var halation = 0.16
    var saturation = 1.08
    var warmth = 0.04
    var monochromeAmount = 0.0
    var phosphorTintRed = 1.0
    var phosphorTintGreen = 1.0
    var phosphorTintBlue = 1.0
    var phosphorPersistence = 0.0

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
                warmth: 0.0,
                monochromeAmount: 0.0,
                phosphorTintRed: 1.0,
                phosphorTintGreen: 1.0,
                phosphorTintBlue: 1.0,
                phosphorPersistence: 0.0
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
                warmth: 0.04,
                monochromeAmount: 0.0,
                phosphorTintRed: 1.0,
                phosphorTintGreen: 1.0,
                phosphorTintBlue: 1.0,
                phosphorPersistence: 0.04
            )

        case .commodore1084:
            return VideoFilterSettings(
                preset: preset,
                scanlineIntensity: 0.30,
                phosphorMaskIntensity: 0.14,
                barrelDistortion: 0.016,
                vignette: 0.14,
                halation: 0.09,
                saturation: 1.10,
                warmth: 0.01,
                monochromeAmount: 0.0,
                phosphorTintRed: 1.0,
                phosphorTintGreen: 1.0,
                phosphorTintBlue: 1.0,
                phosphorPersistence: 0.02
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
                warmth: -0.02,
                monochromeAmount: 0.0,
                phosphorTintRed: 1.0,
                phosphorTintGreen: 1.0,
                phosphorTintBlue: 1.0,
                phosphorPersistence: 0.02
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
                warmth: 0.08,
                monochromeAmount: 0.0,
                phosphorTintRed: 1.0,
                phosphorTintGreen: 1.0,
                phosphorTintBlue: 1.0,
                phosphorPersistence: 0.08
            )

        case .greenPhosphor:
            return VideoFilterSettings(
                preset: preset,
                scanlineIntensity: 0.46,
                phosphorMaskIntensity: 0.0,
                barrelDistortion: 0.035,
                vignette: 0.26,
                halation: 0.30,
                saturation: 1.0,
                warmth: 0.0,
                monochromeAmount: 1.0,
                phosphorTintRed: 0.38,
                phosphorTintGreen: 1.24,
                phosphorTintBlue: 0.34,
                phosphorPersistence: 0.72
            )

        case .amberPhosphor:
            return VideoFilterSettings(
                preset: preset,
                scanlineIntensity: 0.44,
                phosphorMaskIntensity: 0.0,
                barrelDistortion: 0.035,
                vignette: 0.25,
                halation: 0.28,
                saturation: 1.0,
                warmth: 0.0,
                monochromeAmount: 1.0,
                phosphorTintRed: 1.28,
                phosphorTintGreen: 0.80,
                phosphorTintBlue: 0.30,
                phosphorPersistence: 0.62
            )

        case .whitePhosphor:
            return VideoFilterSettings(
                preset: preset,
                scanlineIntensity: 0.40,
                phosphorMaskIntensity: 0.0,
                barrelDistortion: 0.03,
                vignette: 0.22,
                halation: 0.22,
                saturation: 1.0,
                warmth: 0.0,
                monochromeAmount: 1.0,
                phosphorTintRed: 0.96,
                phosphorTintGreen: 1.0,
                phosphorTintBlue: 1.04,
                phosphorPersistence: 0.48
            )
        }
    }
}

enum VideoFilterPreset: String, CaseIterable, Codable, Identifiable {
    case clean = "Clean"
    case commodore1702 = "1702"
    case commodore1084 = "1084"
    case pvm = "PVM"
    case rf = "RF"
    case greenPhosphor = "Green Phosphor"
    case amberPhosphor = "Amber Phosphor"
    case whitePhosphor = "White Phosphor"

    var id: String { rawValue }

    var title: String { rawValue }

    var toolbarTitle: String {
        switch self {
        case .clean:
            return "Clean"
        case .commodore1702:
            return "1702"
        case .commodore1084:
            return "1084"
        case .pvm:
            return "PVM"
        case .rf:
            return "RF"
        case .greenPhosphor:
            return "Green"
        case .amberPhosphor:
            return "Amber"
        case .whitePhosphor:
            return "White"
        }
    }

    var systemImage: String {
        switch self {
        case .clean:
            return "display"
        case .commodore1702, .commodore1084:
            return "tv"
        case .pvm:
            return "rectangle.inset.filled"
        case .rf:
            return "antenna.radiowaves.left.and.right"
        case .greenPhosphor, .amberPhosphor, .whitePhosphor:
            return "sparkles.tv"
        }
    }
}
