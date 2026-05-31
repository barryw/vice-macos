import Foundation

/// Adjustable CRT/display filter settings consumed by `MacVICEMetalRenderer`.
public struct MacVICEVideoFilterSettings: Codable, Equatable, Sendable {
    /// Preset these settings were derived from.
    public var preset: MacVICEVideoFilterPreset
    /// Darkening between scanlines, from 0 to 1.
    public var scanlineIntensity: Double
    /// RGB phosphor mask strength, from 0 to 1.
    public var phosphorMaskIntensity: Double
    /// Barrel distortion amount, from 0 to 1.
    public var barrelDistortion: Double
    /// Corner darkening amount, from 0 to 1.
    public var vignette: Double
    /// Bloom-like glow around bright pixels, from 0 to 1.
    public var halation: Double
    /// Color saturation multiplier.
    public var saturation: Double
    /// Warm/cool color balance offset.
    public var warmth: Double
    /// Amount of monochrome conversion before phosphor tinting, from 0 to 1.
    public var monochromeAmount: Double
    /// Red channel multiplier for monochrome phosphor tinting.
    public var phosphorTintRed: Double
    /// Green channel multiplier for monochrome phosphor tinting.
    public var phosphorTintGreen: Double
    /// Blue channel multiplier for monochrome phosphor tinting.
    public var phosphorTintBlue: Double
    /// Previous-frame persistence amount, from 0 to 1.
    public var phosphorPersistence: Double

    /// Creates custom display filter settings.
    public init(preset: MacVICEVideoFilterPreset = .commodore1702,
                scanlineIntensity: Double = 0.34,
                phosphorMaskIntensity: Double = 0.18,
                barrelDistortion: Double = 0.035,
                vignette: Double = 0.22,
                halation: Double = 0.16,
                saturation: Double = 1.08,
                warmth: Double = 0.04,
                monochromeAmount: Double = 0.0,
                phosphorTintRed: Double = 1.0,
                phosphorTintGreen: Double = 1.0,
                phosphorTintBlue: Double = 1.0,
                phosphorPersistence: Double = 0.0) {
        self.preset = preset
        self.scanlineIntensity = scanlineIntensity
        self.phosphorMaskIntensity = phosphorMaskIntensity
        self.barrelDistortion = barrelDistortion
        self.vignette = vignette
        self.halation = halation
        self.saturation = saturation
        self.warmth = warmth
        self.monochromeAmount = monochromeAmount
        self.phosphorTintRed = phosphorTintRed
        self.phosphorTintGreen = phosphorTintGreen
        self.phosphorTintBlue = phosphorTintBlue
        self.phosphorPersistence = phosphorPersistence
    }

    /// Returns MacVICE's default settings for a preset.
    public static func defaults(for preset: MacVICEVideoFilterPreset) -> MacVICEVideoFilterSettings {
        switch preset {
        case .clean:
            return MacVICEVideoFilterSettings(
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
            return MacVICEVideoFilterSettings(
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
            return MacVICEVideoFilterSettings(
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
            return MacVICEVideoFilterSettings(
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
            return MacVICEVideoFilterSettings(
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
            return MacVICEVideoFilterSettings(
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
            return MacVICEVideoFilterSettings(
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
            return MacVICEVideoFilterSettings(
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

/// Named display filter presets suitable for UI presentation.
public enum MacVICEVideoFilterPreset: String, CaseIterable, Codable, Identifiable, Sendable {
    /// Sharp, unfiltered output.
    case clean = "Clean"
    /// Commodore 1702-inspired composite monitor look.
    case commodore1702 = "1702"
    /// Commodore 1084-inspired RGB monitor look.
    case commodore1084 = "1084"
    /// Professional video monitor-inspired look.
    case pvm = "PVM"
    /// Softer RF-style output.
    case rf = "RF"
    /// Green monochrome phosphor display.
    case greenPhosphor = "Green Phosphor"
    /// Amber monochrome phosphor display.
    case amberPhosphor = "Amber Phosphor"
    /// White monochrome phosphor display.
    case whitePhosphor = "White Phosphor"

    /// Stable identifier for SwiftUI controls.
    public var id: String { rawValue }

    /// Full display title.
    public var title: String { rawValue }

    /// Short display title suitable for compact toolbars.
    public var toolbarTitle: String {
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

    /// SF Symbol name that represents the preset.
    public var systemImage: String {
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
