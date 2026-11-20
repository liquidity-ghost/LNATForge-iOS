import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

@MainActor
public enum Haptics {
    public enum ImpactStyle {
        case light
        case medium
        case rigid
    }

    public static func impact(_ style: ImpactStyle = .light) {
        #if canImport(UIKit)
        let uiStyle: UIImpactFeedbackGenerator.FeedbackStyle
        switch style {
        case .light: uiStyle = .light
        case .medium: uiStyle = .medium
        case .rigid: uiStyle = .rigid
        }
        let generator = UIImpactFeedbackGenerator(style: uiStyle)
        generator.prepare()
        generator.impactOccurred()
        #endif
    }

    public static func selection() {
        #if canImport(UIKit)
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
        #endif
    }

    public static func answer(isCorrect: Bool) {
        #if canImport(UIKit)
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(isCorrect ? .success : .error)
        let impact = UIImpactFeedbackGenerator(style: isCorrect ? .light : .medium)
        impact.impactOccurred()
        #endif
    }

    public static func warning() {
        #if canImport(UIKit)
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.warning)
        #endif
    }
}
