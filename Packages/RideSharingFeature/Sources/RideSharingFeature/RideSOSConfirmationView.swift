import SwiftUI

struct RideSOSConfirmationView: View {
    let onEmergency: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            LiiveColor.scrimStrong
                .ignoresSafeArea()
            VStack(spacing: 0) {
                Text("Emergency Alert")
                    .liiveStyle(.title3)
                    .foregroundColor(LiiveColor.text)
                Text("This will immediately alert emergency services and your emergency contacts. Are you sure?")
                    .font(LiiveFont.footnote)
                    .foregroundColor(LiiveColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 10)
                    .padding(.bottom, 18)
                VStack(spacing: 8) {
                    LiiveButton("Call Emergency Services", variant: .destructive, size: .lg, shape: .capsule, fullWidth: true, action: onEmergency)
                    LiiveButton("Cancel", variant: .plain, fullWidth: true, action: onCancel)
                }
            }
            .padding(22)
            .frame(maxWidth: 300)
            .background(LiiveColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: LiiveRadius.xl, style: .continuous))
        }
        .accessibilityIdentifier(RideAccessibilityIdentifier.sosConfirmation)
    }
}
