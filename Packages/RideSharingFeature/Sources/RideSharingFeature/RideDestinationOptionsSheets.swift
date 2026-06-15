import SwiftUI

struct RideDestinationSheetView: View {
    @ObservedObject var viewModel: RideSharingViewModel

    var body: some View {
        LiiveBottomSheet {
            HStack(alignment: .center) {
                Text("Where to?")
                    .liiveStyle(.title2)
                    .foregroundColor(LiiveColor.text)
                Spacer()
                Text("Now ▾")
                    .font(LiiveFont.footnote.weight(.semibold))
                    .foregroundColor(LiiveColor.accent)
            }
            .padding(.bottom, 12)

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(LiiveColor.textSecondary)
                Text("Search a place or address")
                    .font(LiiveFont.callout)
                    .foregroundColor(LiiveColor.textTertiary)
                Spacer()
            }
            .frame(height: 46)
            .padding(.horizontal, 14)
            .background(LiiveColor.fillTertiary)
            .clipShape(RoundedRectangle(cornerRadius: LiiveRadius.md, style: .continuous))
            .padding(.bottom, 14)

            VStack(spacing: 0) {
                ForEach(Array(RideFixtures.destinations.enumerated()), id: \.element.id) { index, place in
                    LiiveListRow(
                        title: place.title,
                        subtitle: place.subtitle,
                        divider: index < RideFixtures.destinations.count - 1,
                        chevron: true,
                        action: { viewModel.handle(.selectDestination(place)) }
                    ) {
                        LiiveIconCircle(
                            systemName: place.systemImage,
                            color: place.semanticColor.iconColor,
                            size: 36
                        )
                    }
                }
            }
            .background(LiiveColor.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: LiiveRadius.lg, style: .continuous))
        }
    }
}

struct RideOptionsSheetView: View {
    @ObservedObject var viewModel: RideSharingViewModel

    private var state: RideUIState { viewModel.state }
    private var selectedTier: RideTier { state.config.tier }

    var body: some View {
        LiiveBottomSheet {
            header
            tierPicker
            rideDetails
            LiiveButton(
                "Confirm Pickup · \(selectedTier.price.ridePrice)",
                variant: .primary,
                size: .lg,
                shape: .capsule,
                fullWidth: true,
                tabularNumbers: true
            ) {
                viewModel.handle(.confirmPickup)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Button(action: { viewModel.handle(.backToDestination) }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(LiiveColor.text)
                    .frame(width: 32, height: 32)
                    .background(LiiveColor.fillTertiary)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text("Choose your ride")
                    .liiveStyle(.title3)
                    .foregroundColor(LiiveColor.text)
                Text("to \(state.destination?.title ?? "Union Square")")
                    .font(LiiveFont.footnote)
                    .foregroundColor(LiiveColor.textSecondary)
            }
            Spacer()
        }
        .padding(.bottom, 12)
    }

    private var tierPicker: some View {
        VStack(spacing: 8) {
            ForEach(RideTier.allCases) { tier in
                RideTierRow(tier: tier, isSelected: tier == selectedTier) {
                    viewModel.handle(.selectTier(tier))
                }
            }
        }
        .padding(.bottom, 14)
    }

    private var rideDetails: some View {
        VStack(spacing: 0) {
            LiiveListRow(title: "Passengers") {
                LiiveIconCircle(systemName: "person.2.fill", color: .neutral, size: 32)
            } trailing: {
                LiiveStepper(value: state.config.passengers, range: 1...4) {
                    viewModel.handle(.setPassengers($0))
                }
            }
            LiiveListRow(title: "Bags") {
                LiiveIconCircle(systemName: "suitcase.fill", color: .neutral, size: 32)
            } trailing: {
                LiiveStepper(value: state.config.bags, range: 0...4) {
                    viewModel.handle(.setBags($0))
                }
            }
            LiiveListRow(title: "Female-only pool", subtitle: "Match same-gender drivers & riders") {
                LiiveIconCircle(systemName: "shield.lefthalf.filled", color: .success, size: 32)
            } trailing: {
                LiiveSwitch(isOn: Binding(
                    get: { state.config.femaleOnly },
                    set: { viewModel.handle(.setFemaleOnly($0)) }
                ))
            }
            LiiveListRow(title: "Child seat", divider: false) {
                LiiveIconCircle(systemName: "figure.child", color: .neutral, size: 32)
            } trailing: {
                LiiveSwitch(isOn: Binding(
                    get: { state.config.childSeat },
                    set: { viewModel.handle(.setChildSeat($0)) }
                ))
            }
        }
        .background(LiiveColor.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: LiiveRadius.lg, style: .continuous))
        .padding(.bottom, 14)
    }
}

private struct RideTierRow: View {
    let tier: RideTier
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                LiiveIconCircle(systemName: tier.systemImage, color: isSelected ? .accent : .neutral)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(tier.name)
                            .font(LiiveFont.headline)
                            .foregroundColor(LiiveColor.text)
                        if tier.isMultiLeg {
                            LiiveBadge("2 legs", color: .warning)
                        }
                    }
                    Text(tier.detail)
                        .font(LiiveFont.footnote)
                        .foregroundColor(LiiveColor.textSecondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(tier.price.ridePrice)
                        .font(LiiveFont.headline.monospacedDigit())
                        .foregroundColor(LiiveColor.text)
                    Text(tier.eta)
                        .font(LiiveFont.caption1.monospacedDigit())
                        .foregroundColor(LiiveColor.textSecondary)
                }
            }
            .padding(12)
            .background(LiiveColor.surfaceRaised)
            .overlay(
                RoundedRectangle(cornerRadius: LiiveRadius.lg, style: .continuous)
                    .strokeBorder(isSelected ? LiiveColor.accent : .clear, lineWidth: 1.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: LiiveRadius.lg, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

extension Double {
    var ridePrice: String {
        String(format: "$%.2f", self)
    }
}
