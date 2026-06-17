import SwiftUI

struct RideChromeView: View {
    let state: RideUIState
    let onLocate: () -> Void
    let onToggleMic: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            if state.phase == .enroute {
                LiiveGlassPanel(material: .thin, cornerRadius: LiiveRadius.full, padding: RideChromeLayout.glassPanelPadding) {
                    LiiveBadge("Voice connected", color: .success, dot: true)
                        .padding(.horizontal, RideChromeLayout.badgeHorizontalPadding)
                        .padding(.vertical, RideChromeLayout.badgeVerticalPadding)
                }
            } else {
                Spacer().frame(width: RideChromeLayout.placeholderSize, height: RideChromeLayout.placeholderSize)
            }
            Spacer()
            HStack(spacing: RideChromeLayout.buttonSpacing) {
                if state.phase == .enroute {
                    chromeButton(
                        systemName: state.micEnabled ? "mic.fill" : "mic.slash.fill",
                        color: state.micEnabled ? LiiveColor.text : LiiveColor.danger,
                        action: onToggleMic
                    )
                }
                chromeButton(systemName: "location.circle.fill", color: LiiveColor.accent, action: onLocate)
            }
        }
        .padding(.horizontal, RideChromeLayout.horizontalPadding)
        .padding(.top, RideChromeLayout.topInset)
        .accessibilityIdentifier(RideAccessibilityIdentifier.topChrome)
    }

    private func chromeButton(systemName: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            LiiveGlassPanel(material: .thin, cornerRadius: LiiveRadius.full, padding: RideChromeLayout.glassPanelPadding) {
                Image(systemName: systemName)
                    .font(.system(size: RideChromeLayout.buttonIconSize, weight: RideChromeLayout.buttonIconWeight))
                    .foregroundColor(color)
                    .frame(width: RideChromeLayout.buttonSize, height: RideChromeLayout.buttonSize)
            }
        }
        .buttonStyle(.plain)
    }
}
