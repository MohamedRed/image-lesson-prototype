//  LiiveSegmentedControl.swift
//  Liive Ride - "TIDE" segmented control (SwiftUI)

import SwiftUI

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
                HStack(spacing: 0) {
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
                .padding(LiiveSpacing.xs2)
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
                .liiveStyle(.subhead)
                .fontWeight(isSelected ? .semibold : .medium)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .foregroundColor(isSelected ? LiiveColor.text : LiiveColor.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, LiiveSpacing.m)
                .padding(.vertical, LiiveSpacing.s)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private func selectedPill(in size: CGSize) -> some View {
        let segmentWidth = size.width / CGFloat(options.count)
        let selectedOffset = segmentWidth * CGFloat(selectedIndex)

        return RoundedRectangle(cornerRadius: LiiveRadius.sm, style: .continuous)
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
