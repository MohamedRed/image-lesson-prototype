import SwiftUI

struct RideChromeView: View {
    let state: RideUIState
    let onLocate: () -> Void
    let onToggleMic: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            if state.phase == .enroute {
                LiiveGlassPanel(material: .thin, cornerRadius: LiiveRadius.full, padding: 7) {
                    LiiveBadge("Voice connected", color: .success, dot: true)
                }
            } else {
                Spacer().frame(width: 1, height: 1)
            }
            Spacer()
            HStack(spacing: 8) {
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
        .padding(.horizontal, 16)
        .padding(.top, 58)
    }

    private func chromeButton(systemName: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            LiiveGlassPanel(material: .thin, cornerRadius: LiiveRadius.full, padding: 0) {
                Image(systemName: systemName)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(color)
                    .frame(width: 44, height: 44)
            }
        }
        .buttonStyle(.plain)
    }
}
