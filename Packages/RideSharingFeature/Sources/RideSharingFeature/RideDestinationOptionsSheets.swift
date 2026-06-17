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
                    .font(LiiveFont.sheetMetaSemibold)
                    .foregroundColor(LiiveColor.accent)
            }
            .padding(.bottom, RideSheetLayout.headerBottomPadding)

            HStack(spacing: RideSheetLayout.rowGap) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: RideSheetLayout.searchIconSize, weight: .semibold))
                    .foregroundColor(LiiveColor.textSecondary)
                Text("Search a place or address")
                    .font(LiiveFont.callout)
                    .foregroundColor(LiiveColor.textTertiary)
                Spacer()
            }
            .frame(height: RideSheetLayout.searchHeight)
            .padding(.horizontal, RideSheetLayout.searchHorizontalPadding)
            .background(LiiveColor.fillTertiary)
            .clipShape(RoundedRectangle(cornerRadius: LiiveRadius.md, style: .continuous))
            .padding(.bottom, RideSheetLayout.sectionGap)

            VStack(spacing: RideSheetLayout.stackedSpacing) {
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
                            size: RideSheetLayout.savedPlaceIconSize
                        )
                    }
                }
            }
            .background(LiiveColor.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: LiiveRadius.lg, style: .continuous))
        }
        .accessibilityIdentifier(RideAccessibilityIdentifier.destinationSheet)
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
        .accessibilityIdentifier(RideAccessibilityIdentifier.optionsSheet)
    }

    private var header: some View {
        HStack(spacing: RideSheetLayout.rowGap) {
            Button(action: { viewModel.handle(.backToDestination) }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: RideSheetLayout.backIconSize, weight: .semibold))
                    .foregroundColor(LiiveColor.text)
                    .frame(width: RideSheetLayout.backButtonSize, height: RideSheetLayout.backButtonSize)
                    .background(LiiveColor.fillTertiary)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: RideSheetLayout.compactGap) {
                Text("Choose your ride")
                    .liiveStyle(.title3)
                    .foregroundColor(LiiveColor.text)
                Text("to \(state.destination?.title ?? "Union Square")")
                    .font(LiiveFont.footnote)
                    .foregroundColor(LiiveColor.textSecondary)
            }
            Spacer()
        }
        .padding(.bottom, RideSheetLayout.headerBottomPadding)
    }

    private var tierPicker: some View {
        VStack(spacing: RideSheetLayout.tierSpacing) {
            ForEach(RideTier.allCases) { tier in
                RideTierRow(tier: tier, isSelected: tier == selectedTier) {
                    viewModel.handle(.selectTier(tier))
                }
            }
        }
        .padding(.bottom, RideSheetLayout.sectionGap)
    }

    private var rideDetails: some View {
        VStack(spacing: RideSheetLayout.stackedSpacing) {
            LiiveListRow(title: "Passengers") {
                LiiveIconCircle(systemName: "person.2.fill", color: .neutral, size: RideSheetLayout.optionIconSize)
            } trailing: {
                LiiveStepper(value: state.config.passengers, range: 1...4) {
                    viewModel.handle(.setPassengers($0))
                }
            }
            LiiveListRow(title: "Bags") {
                LiiveIconCircle(systemName: "suitcase.fill", color: .neutral, size: RideSheetLayout.optionIconSize)
            } trailing: {
                LiiveStepper(value: state.config.bags, range: 0...4) {
                    viewModel.handle(.setBags($0))
                }
            }
            LiiveListRow(title: "Female-only pool", subtitle: "Match same-gender drivers & riders") {
                LiiveIconCircle(systemName: "shield.lefthalf.filled", color: .success, size: RideSheetLayout.optionIconSize)
            } trailing: {
                LiiveSwitch(isOn: Binding(
                    get: { state.config.femaleOnly },
                    set: { viewModel.handle(.setFemaleOnly($0)) }
                ))
            }
            LiiveListRow(title: "Child seat", divider: false) {
                LiiveIconCircle(systemName: "figure.child", color: .neutral, size: RideSheetLayout.optionIconSize)
            } trailing: {
                LiiveSwitch(isOn: Binding(
                    get: { state.config.childSeat },
                    set: { viewModel.handle(.setChildSeat($0)) }
                ))
            }
        }
        .background(LiiveColor.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: LiiveRadius.lg, style: .continuous))
        .padding(.bottom, RideSheetLayout.sectionGap)
    }
}

private struct RideTierRow: View {
    let tier: RideTier
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: RideSheetLayout.headerBottomPadding) {
                LiiveIconCircle(systemName: tier.systemImage, color: isSelected ? .accent : .neutral)
                VStack(alignment: .leading, spacing: RideSheetLayout.compactGap + RideSheetLayout.compactGap / 2) {
                    HStack(spacing: RideSheetLayout.inlineGap) {
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
                VStack(alignment: .trailing, spacing: RideSheetLayout.compactGap) {
                    Text(tier.price.ridePrice)
                        .font(LiiveFont.headline.monospacedDigit())
                        .fontWeight(.bold)
                        .foregroundColor(LiiveColor.text)
                    Text(tier.eta)
                        .font(LiiveFont.caption1.monospacedDigit())
                        .foregroundColor(LiiveColor.textSecondary)
                }
            }
            .padding(RideSheetLayout.tierRowPadding)
            .background(LiiveColor.surfaceRaised)
            .overlay(
                RoundedRectangle(cornerRadius: LiiveRadius.lg, style: .continuous)
                    .strokeBorder(isSelected ? LiiveColor.accent : .clear, lineWidth: RideSheetLayout.selectedBorderWidth)
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
