import SwiftUI

public struct CreditPopupView: View {
    @Environment(\.lnatPalette) private var palette

    public let onDismiss: () -> Void

    @State private var cardAppeared = false

    public init(onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
    }

    public var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(Color.black.opacity(palette.isDark ? 0.56 : 0.30))
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(palette.accentSecondaryText)
                    .frame(width: 56, height: 56)
                    .background(palette.bgSoftAccent)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(palette.borderSubtle, lineWidth: 1)
                    )

                Text("LNAT Forge")
                    .font(.system(size: 21, weight: .bold))
                    .foregroundStyle(palette.textPrimary)

                Text("“Crafted in a quiet West Coast town, fueled by good coffee and late nights, and sparked by lil Isla’s LNAT prep. Open-sourced for the world. Freely yours to study, remix, and conquer. Free, open, and ad-free forever”")
                    .font(.system(size: 15, design: .serif))
                    .lineSpacing(6)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(palette.textPrimary.opacity(0.92))
                    .fixedSize(horizontal: false, vertical: true)

                Divider()
                    .overlay(palette.borderSubtle)
                    .padding(.vertical, 4)

                Text("© Tom Legacy")
                    .font(.system(size: 12, weight: .medium))
                    .tracking(0.5)
                    .foregroundStyle(palette.textSecondary)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 26)
            .frame(maxWidth: 344)
            .background(palette.bgSurface)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(palette.borderSubtle, lineWidth: 1)
            )
            .shadow(
                color: palette.isDark ? Color.black.opacity(0.55) : palette.textPrimary.opacity(0.14),
                radius: 28,
                x: 0,
                y: 12
            )
            .padding(.horizontal, 24)
            .scaleEffect(cardAppeared ? 1.0 : 0.92)
            .opacity(cardAppeared ? 1.0 : 0.0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            onDismiss()
        }
        .onAppear {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                cardAppeared = true
            }
        }
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape) {
            onDismiss()
        }
    }
}
