import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public enum AppTab: Int, CaseIterable, Hashable, Identifiable {
    case learn = 0
    case review = 1
    case progress = 2
    case essays = 3

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .learn: return "Learn"
        case .review: return "Review"
        case .progress: return "Progress"
        case .essays: return "Essays"
        }
    }

    public var iconName: String {
        switch self {
        case .learn: return "book.closed.fill"
        case .review: return "doc.text.magnifyingglass"
        case .progress: return "waveform.path.ecg"
        case .essays: return "pencil.and.outline"
        }
    }
}

public struct RootTabView: View {
    @Environment(\.colorScheme) private var systemColorScheme
    @AppStorage("lnat-forge-theme") private var themeModeRaw: String = ThemeMode.system.rawValue

    public let contentStore: ContentStore

    @State private var activeTab: AppTab = .learn
    @State private var scrolledTab: AppTab? = .learn
    @State private var dragTabProgress: CGFloat = 0
    @State private var selectedLearnTopic: LnatTopic?
    @State private var showCreditPopup = false
    @State private var themeToggleHapticTrigger = 0
    @State private var isReviewAtRoot = true
    @State private var isProgressSettingsOpen = false
    @State private var reviewResetTrigger = 0
    @State private var isKeyboardVisible = false

    public init(contentStore: ContentStore = .shared) {
        self.contentStore = contentStore
    }

    private var themeMode: ThemeMode {
        ThemeMode(rawValue: themeModeRaw) ?? .system
    }

    private var resolvedScheme: ColorScheme {
        themeMode.resolvedColorScheme(system: systemColorScheme)
    }

    private var palette: LNATPalette {
        LNATPalette.resolve(for: resolvedScheme)
    }

    private var usesLiveScrollProgress: Bool {
        if #available(iOS 18.0, *) {
            return true
        } else {
            return false
        }
    }

    private var canSwipeBetweenTabs: Bool {
        guard !showCreditPopup && !isKeyboardVisible else { return false }
        switch activeTab {
        case .learn:
            return selectedLearnTopic == nil
        case .review:
            return isReviewAtRoot
        case .progress:
            return !isProgressSettingsOpen
        case .essays:
            return true
        }
    }

    public var body: some View {
        ZStack {
            VStack(spacing: 0) {
                appHeader

                tabPager
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()

                if !isKeyboardVisible {
                    floatingTabBar
                }
            }
            .background(palette.bgApp.ignoresSafeArea())

            if showCreditPopup {
                CreditPopupView {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                        showCreditPopup = false
                    }
                }
                .transition(.opacity)
                .zIndex(100)
            }
        }
        .environment(\.lnatPalette, palette)
        .environment(\.colorScheme, resolvedScheme)
        .sensoryFeedback(.selection, trigger: activeTab)
        .sensoryFeedback(.impact(weight: .light), trigger: showCreditPopup)
        .sensoryFeedback(.impact(weight: .light), trigger: themeToggleHapticTrigger)
        .onAppear {
            themeMode.applyWindowInterfaceStyle()
            DispatchQueue.main.async {
                themeMode.applyWindowInterfaceStyle()
            }
        }
        .onChange(of: themeModeRaw) { _, _ in
            themeMode.applyWindowInterfaceStyle()
        }
        #if canImport(UIKit)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            isKeyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            isKeyboardVisible = false
        }
        #endif
    }

    // MARK: - Interactive Horizontal Tab Pager

    private var tabPager: some View {
        GeometryReader { geo in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    LearnTabView(
                        selectedTopic: $selectedLearnTopic,
                        contentStore: contentStore
                    )
                    .frame(width: geo.size.width, height: geo.size.height)
                    .id(AppTab.learn)

                    ReviewTabView(
                        contentStore: contentStore,
                        isAtRoot: $isReviewAtRoot,
                        resetToRootTrigger: reviewResetTrigger
                    )
                    .frame(width: geo.size.width, height: geo.size.height)
                    .id(AppTab.review)

                    ProgressTabView(
                        themeModeRaw: $themeModeRaw,
                        contentStore: contentStore,
                        onTrainTopic: { topic in
                            withAnimation(.snappy(duration: 0.30, extraBounce: 0.0)) {
                                activeTab = .learn
                                scrolledTab = .learn
                                if !usesLiveScrollProgress {
                                    dragTabProgress = 0
                                }
                            }
                            selectedLearnTopic = topic
                        },
                        onSettingsOpenChanged: { open in
                            isProgressSettingsOpen = open
                        }
                    )
                    .frame(width: geo.size.width, height: geo.size.height)
                    .id(AppTab.progress)

                    EssaysTabView(contentStore: contentStore)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .id(AppTab.essays)
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $scrolledTab)
            .scrollDisabled(!canSwipeBetweenTabs)
            .modifier(TabPagerProgressModifier(tabCount: AppTab.allCases.count, progress: $dragTabProgress))
            .onChange(of: scrolledTab) { _, newTab in
                guard let newTab else { return }
                if activeTab != newTab {
                    activeTab = newTab
                }
                if !usesLiveScrollProgress {
                    withAnimation(.snappy) {
                        dragTabProgress = CGFloat(newTab.rawValue)
                    }
                }
            }
        }
    }

    // MARK: - Header

    private var appHeader: some View {
        HStack(spacing: 4) {
            HStack(spacing: 4) {
                Button {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
                        showCreditPopup = true
                    }
                } label: {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(palette.accentSecondaryText)
                        .frame(width: 32, height: 32)
                        .background(palette.bgSoftAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(palette.borderSubtle, lineWidth: 1)
                        )
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(TactileScaleButtonStyle())
                .accessibilityLabel("About LNAT Forge")

                Text("LNAT Forge")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(palette.textPrimary)
            }

            Spacer()

            Button {
                themeToggleHapticTrigger += 1
                let nextMode: ThemeMode = resolvedScheme == .dark ? .light : .dark
                themeModeRaw = nextMode.rawValue
                nextMode.applyWindowInterfaceStyle()
            } label: {
                Image(systemName: resolvedScheme == .dark ? "sun.max.fill" : "moon.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(palette.accentPrimary)
                    .frame(width: 36, height: 36)
                    .background(palette.bgMuted)
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .stroke(palette.borderSubtle, lineWidth: 1)
                    )
            }
            .buttonStyle(TactileScaleButtonStyle())
            .accessibilityLabel(resolvedScheme == .dark ? "Switch to light theme" : "Switch to dark theme")
        }
        .padding(.leading, 10)
        .padding(.trailing, 16)
        .padding(.vertical, 4)
        .background(palette.bgSurface.ignoresSafeArea(edges: .top))
        .overlay(alignment: .bottom) {
            Rectangle().fill(palette.borderSubtle).frame(height: 1)
        }
    }

    // MARK: - Docked Floating Tab Bar

    private var floatingTabBar: some View {
        let highlightedTab = AppTab(rawValue: Int(dragTabProgress.rounded())) ?? activeTab

        return ZStack(alignment: .leading) {
            GeometryReader { geo in
                let tabCount = CGFloat(AppTab.allCases.count)
                let slotWidth = geo.size.width / max(1, tabCount)

                Capsule()
                    .fill(palette.bgSoftAccent.opacity(palette.isDark ? 0.92 : 0.85))
                    .frame(width: max(0, slotWidth - 4), height: geo.size.height)
                    .offset(x: slotWidth * dragTabProgress + 2)
            }
            .allowsHitTesting(false)

            HStack(spacing: 0) {
                ForEach(AppTab.allCases) { tab in
                    let isSelected = highlightedTab == tab
                    Button {
                        selectTab(tab)
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: tab.iconName)
                                .font(.system(size: 16, weight: isSelected ? .semibold : .medium))
                            Text(tab.title)
                                .font(.system(size: 10.5, weight: isSelected ? .bold : .medium))
                        }
                        .foregroundStyle(isSelected ? palette.accentPrimary : palette.textSecondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
        .frame(height: 48)
        .padding(6)
        .background {
            Capsule()
                .fill(.regularMaterial)
                .overlay(
                    Capsule()
                        .fill(palette.bgSurface.opacity(palette.isDark ? 0.92 : 0.94))
                )
        }
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(palette.borderSubtle, lineWidth: 1)
        )
        .shadow(
            color: palette.isDark ? Color.black.opacity(0.45) : palette.textPrimary.opacity(0.10),
            radius: 14,
            x: 0,
            y: 5
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity)
        .background {
            palette.bgApp
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private func selectTab(_ tab: AppTab) {
        if tab == .learn && activeTab == .learn {
            selectedLearnTopic = nil
        } else if tab == .review && activeTab == .review {
            reviewResetTrigger += 1
        }
        withAnimation(.snappy(duration: 0.30, extraBounce: 0.0)) {
            activeTab = tab
            scrolledTab = tab
            if !usesLiveScrollProgress {
                dragTabProgress = CGFloat(tab.rawValue)
            }
        }
    }
}

private struct TabPagerProgressModifier: ViewModifier {
    let tabCount: Int
    @Binding var progress: CGFloat

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.onScrollGeometryChange(for: CGFloat.self) { geometry in
                let width = geometry.containerSize.width
                guard width > 0 else { return 0 }
                let raw = geometry.contentOffset.x / width
                return min(max(raw, 0), CGFloat(max(0, tabCount - 1)))
            } action: { _, newValue in
                progress = newValue
            }
        } else {
            content
        }
    }
}
