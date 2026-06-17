//  LiiveSegmentedControl.swift
//  Liive Ride - "TIDE" segmented control (SwiftUI)

import SwiftUI

private enum LiiveSegmentedMetrics {
    static let fontSize = LiiveSpacing.m + LiiveSpacing.xs2
    static let verticalPadding = LiiveSpacing.s - LiiveSpacing.xs2 / 2
    static let horizontalPadding = LiiveSpacing.m
    static let containerSpacing = CGFloat.zero
    static let containerInset = LiiveSpacing.xs2
    static let selectedPillRadius = LiiveSpacing.s - LiiveSpacing.xs2 / 2
    static let minimumScaleFactor = 0.85
}

public struct LiiveSegmentedOption<Value: Hashable>: Identifiable, Hashable {
    public let id: Value
    public let title: String

    public init(id: Value, title: String) {
        self.id = id
        self.title = title
    }
}

public struct LiiveSegmentedControl<Value: Hashable>: View {
    private let options: [LiiveSegmentedOption<Value>]
    @Binding private var selection: Value

    public init(options: [LiiveSegmentedOption<Value>], selection: Binding<Value>) {
        self.options = options
        _selection = selection
    }

    public var body: some View {
        Group {
            if !options.isEmpty {
                HStack(spacing: LiiveSegmentedMetrics.containerSpacing) {
                    ForEach(options) { option in
                        segment(option)
                    }
                }
                .background(alignment: .leading) {
                    GeometryReader { proxy in
                        selectedPill(in: proxy.size)
                    }
                    .allowsHitTesting(false)
                }
                .padding(LiiveSegmentedMetrics.containerInset)
                .background(LiiveColor.fillTertiary)
                .clipShape(RoundedRectangle(cornerRadius: LiiveRadius.sm, style: .continuous))
            }
        }
    }

    private func segment(_ option: LiiveSegmentedOption<Value>) -> some View {
        let isSelected = option.id == selection

        return Button {
            withAnimation(.easeOut(duration: LiiveMotion.fast)) {
                selection = option.id
            }
        } label: {
            Text(option.title)
                .font(Font.custom(LiiveFont.family, size: LiiveSegmentedMetrics.fontSize))
                .fontWeight(isSelected ? .semibold : .medium)
                .lineLimit(1)
                .minimumScaleFactor(LiiveSegmentedMetrics.minimumScaleFactor)
                .foregroundColor(isSelected ? LiiveColor.text : LiiveColor.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, LiiveSegmentedMetrics.horizontalPadding)
                .padding(.vertical, LiiveSegmentedMetrics.verticalPadding)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private func selectedPill(in size: CGSize) -> some View {
        let segmentWidth = size.width / CGFloat(options.count)
        let selectedOffset = segmentWidth * CGFloat(selectedIndex)

        return RoundedRectangle(cornerRadius: LiiveSegmentedMetrics.selectedPillRadius, style: .continuous)
            .fill(LiiveColor.surfaceRaised)
            .frame(width: segmentWidth)
            .liiveShadow(.small)
            .offset(x: selectedOffset)
            .animation(.easeOut(duration: LiiveMotion.base), value: selectedIndex)
    }

    private var selectedIndex: Int {
        options.firstIndex { $0.id == selection } ?? 0
    }
}
