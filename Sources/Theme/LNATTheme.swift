import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public enum ThemeMode: String, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    public var iconName: String {
        switch self {
        case .system: return "display"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }

    public var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    public func resolvedColorScheme(system: ColorScheme) -> ColorScheme {
        switch self {
        case .system: return system
        case .light: return .light
        case .dark: return .dark
        }
    }

    @MainActor
    public func applyWindowInterfaceStyle() {
        #if canImport(UIKit)
        let style: UIUserInterfaceStyle
        switch self {
        case .system: style = .unspecified
        case .light: style = .light
        case .dark: style = .dark
        }
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                window.overrideUserInterfaceStyle = style
            }
        }
        #endif
    }

    public func statusLabel(resolvedScheme: ColorScheme) -> String {
        switch self {
        case .system:
            return resolvedScheme == .dark ? "Auto (Dark)" : "Auto (Light)"
        case .light:
            return "Sakura Light"
        case .dark:
            return "Pastel Dusk"
        }
    }
}

public struct LNATPalette: Sendable {
    public let isDark: Bool
    public let bgApp: Color
    public let bgSurface: Color
    public let bgSoftAccent: Color
    public let bgMuted: Color
    public let textPrimary: Color
    public let textSecondary: Color
    public let accentPrimary: Color
    public let accentPrimaryFg: Color
    public let accentSecondary: Color
    public let accentSecondaryText: Color
    public let accentBlue: Color
    public let accentBlueText: Color
    public let borderSubtle: Color

    public let statusCorrectBg: Color
    public let statusCorrectBorder: Color
    public let statusCorrectText: Color
    public let statusCorrectSolid: Color
    public let statusCorrectSolidFg: Color

    public let statusTrapBg: Color
    public let statusTrapBorder: Color
    public let statusTrapText: Color
    public let statusTrapSolid: Color
    public let statusTrapSolidFg: Color

    public static let sakuraLight = LNATPalette(
        isDark: false,
        bgApp: Color(hex: 0xFDF2F8),
        bgSurface: Color(hex: 0xFFFFFF),
        bgSoftAccent: Color(hex: 0xFCE7F3),
        bgMuted: Color(hex: 0xFDF2F8),
        textPrimary: Color(hex: 0x1E1B4B),
        textSecondary: Color(hex: 0x4C1D95),
        accentPrimary: Color(hex: 0x1E3A8A),
        accentPrimaryFg: Color(hex: 0xFFFFFF),
        accentSecondary: Color(hex: 0xEC4899),
        accentSecondaryText: Color(hex: 0xBE185D),
        accentBlue: Color(hex: 0x38BDF8),
        accentBlueText: Color(hex: 0x0369A1),
        borderSubtle: Color(hex: 0xFBCFE8),
        statusCorrectBg: Color(hex: 0xECFDF5),
        statusCorrectBorder: Color(hex: 0x6EE7B7),
        statusCorrectText: Color(hex: 0x065F46),
        statusCorrectSolid: Color(hex: 0x047857),
        statusCorrectSolidFg: Color(hex: 0xFFFFFF),
        statusTrapBg: Color(hex: 0xFFF1F2),
        statusTrapBorder: Color(hex: 0xFDA4AF),
        statusTrapText: Color(hex: 0x9F1239),
        statusTrapSolid: Color(hex: 0xBE123C),
        statusTrapSolidFg: Color(hex: 0xFFFFFF)
    )

    public static let pastelDusk = LNATPalette(
        isDark: true,
        bgApp: Color(hex: 0x0B0F19),
        bgSurface: Color(hex: 0x131B2E),
        bgSoftAccent: Color(hex: 0x3B1D36),
        bgMuted: Color(hex: 0x0B0F19),
        textPrimary: Color(hex: 0xF8FAFC),
        textSecondary: Color(hex: 0x94A3B8),
        accentPrimary: Color(hex: 0x7DD3FC),
        accentPrimaryFg: Color(hex: 0x0B0F19),
        accentSecondary: Color(hex: 0xF9A8D4),
        accentSecondaryText: Color(hex: 0xF9A8D4),
        accentBlue: Color(hex: 0x38BDF8),
        accentBlueText: Color(hex: 0x38BDF8),
        borderSubtle: Color(hex: 0x1E293B),
        statusCorrectBg: Color(hex: 0x10B981).opacity(0.15),
        statusCorrectBorder: Color(hex: 0x34D399).opacity(0.40),
        statusCorrectText: Color(hex: 0x6EE7B7),
        statusCorrectSolid: Color(hex: 0x34D399),
        statusCorrectSolidFg: Color(hex: 0x020617),
        statusTrapBg: Color(hex: 0xF43F5E).opacity(0.15),
        statusTrapBorder: Color(hex: 0xFB7185).opacity(0.40),
        statusTrapText: Color(hex: 0xFDA4AF),
        statusTrapSolid: Color(hex: 0xFB7185),
        statusTrapSolidFg: Color(hex: 0x020617)
    )

    public static func resolve(for colorScheme: ColorScheme) -> LNATPalette {
        colorScheme == .dark ? .pastelDusk : .sakuraLight
    }
}

public extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

private struct LNATPaletteKey: EnvironmentKey {
    static let defaultValue: LNATPalette = .sakuraLight
}

public extension EnvironmentValues {
    var lnatPalette: LNATPalette {
        get { self[LNATPaletteKey.self] }
        set { self[LNATPaletteKey.self] = newValue }
    }
}
