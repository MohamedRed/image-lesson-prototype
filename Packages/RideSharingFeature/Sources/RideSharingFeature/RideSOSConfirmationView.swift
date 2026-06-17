import SwiftUI

struct RideSOSConfirmationView: View {
    let onEmergency: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            LiiveColor.scrimStrong
                .ignoresSafeArea()
            VStack(spacing: RideSheetLayout.stackedSpacing) {
                Text("Emergency Alert")
                    .liiveStyle(.title3)
                    .foregroundColor(LiiveColor.text)
                Text("This will immediately alert emergency services and your emergency contacts. Are you sure?")
                    .font(LiiveFont.footnote)
                    .foregroundColor(LiiveColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, RideSheetLayout.sosMessageTopPadding)
                    .padding(.bottom, RideSheetLayout.sosMessageBottomPadding)
                VStack(spacing: RideSheetLayout.sosButtonGap) {
                    LiiveButton("Call Emergency Services", variant: .destructive, size: .lg, shape: .capsule, fullWidth: true, action: onEmergency)
                    LiiveButton("Cancel", variant: .plain, fullWidth: true, action: onCancel)
                }
            }
            .padding(RideSheetLayout.sosPanelPadding)
            .frame(maxWidth: RideSheetLayout.sosPanelMaxWidth)
            .background(LiiveColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: LiiveRadius.xl, style: .continuous))
        }
        .accessibilityIdentifier(RideAccessibilityIdentifier.sosConfirmation)
    }
}
