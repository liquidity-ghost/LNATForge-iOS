import SwiftUI
#if canImport(UIKit)
import ObjectiveC
import UIKit
#endif

// MARK: - Interactive Pop Gesture Support

#if canImport(UIKit)
@MainActor
private enum PopGestureAssociatedKey {
    static var delegate: UInt8 = 0
}

private final class PersistentPopGestureDelegate: NSObject, UIGestureRecognizerDelegate {
    weak var navigationController: UINavigationController?

    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let nav = navigationController else { return false }
        return nav.viewControllers.count > 1 && nav.transitionCoordinator == nil
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        guard let nav = navigationController else { return false }
        return nav.viewControllers.count > 1
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        false
    }
}

private final class InteractivePopGestureBridgeVC: UIViewController {
    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        configurePopGesture()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        configurePopGesture()
    }

    private func configurePopGesture() {
        var current: UIViewController? = self
        var foundNav: UINavigationController?
        while let vc = current {
            if let nav = vc as? UINavigationController ?? vc.navigationController {
                foundNav = nav
                break
            }
            current = vc.parent
        }
        guard let nav = foundNav, let popGesture = nav.interactivePopGestureRecognizer else { return }

        let delegate: PersistentPopGestureDelegate
        if let existing = objc_getAssociatedObject(nav, &PopGestureAssociatedKey.delegate) as? PersistentPopGestureDelegate {
            delegate = existing
        } else {
            let created = PersistentPopGestureDelegate(navigationController: nav)
            objc_setAssociatedObject(
                nav,
                &PopGestureAssociatedKey.delegate,
                created,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
            delegate = created
        }

        popGesture.isEnabled = true
        popGesture.delegate = delegate
    }
}

private struct InteractivePopGestureBridge: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> InteractivePopGestureBridgeVC {
        InteractivePopGestureBridgeVC()
    }

    func updateUIViewController(_ uiViewController: InteractivePopGestureBridgeVC, context: Context) {}
}
#endif

public extension View {
    func enableInteractivePopGesture() -> some View {
        #if canImport(UIKit)
        background(
            InteractivePopGestureBridge()
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)
        )
        #else
        self
        #endif
    }
}

// MARK: - Horizontal Scroll Gesture Exclusion

public struct HorizontalScrollRectsPreferenceKey: PreferenceKey {
    public static let defaultValue: [CGRect] = []

    public static func reduce(value: inout [CGRect], nextValue: () -> [CGRect]) {
        value.append(contentsOf: nextValue())
    }
}

public extension View {
    func excludeFromTabSwipe() -> some View {
        background(
            GeometryReader { proxy in
                Color.clear
                    .preference(
                        key: HorizontalScrollRectsPreferenceKey.self,
                        value: [proxy.frame(in: .global)]
                    )
            }
        )
    }
}

// MARK: - Tactile Press Feedback Button Styles

public struct TactileCardButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

public struct TactileScaleButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
