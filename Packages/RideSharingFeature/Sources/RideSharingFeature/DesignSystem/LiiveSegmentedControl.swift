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
        HStack(spacing: LiiveSpacing.xs) {
            ForEach(options) { option in
                segment(option)
            }
        }
        .padding(LiiveSpacing.xs)
        .background(LiiveColor.fillTertiary)
        .clipShape(RoundedRectangle(cornerRadius: LiiveRadius.full, style: .continuous))
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
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .foregroundColor(isSelected ? LiiveColor.text : LiiveColor.textSecondary)
                .frame(maxWidth: .infinity)
                .frame(minHeight: LiiveControl.md - LiiveSpacing.s)
                .padding(.horizontal, LiiveSpacing.m)
                .background(isSelected ? LiiveColor.surfaceRaised : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: LiiveRadius.full, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
