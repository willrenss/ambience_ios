import SwiftUI

// Primary coral action button per the design system.
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.labelLarge)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .foregroundStyle(.white)
            .background(Color.coral.opacity(configuration.isPressed ? 0.8 : 1),
                        in: RoundedRectangle(cornerRadius: Radius.chip))
    }
}

// Outlined, lower-emphasis action (e.g. "Skip" next to a primary "Enable").
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.labelLarge)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .foregroundStyle(Color.terracotta)
            .background(Color.white.opacity(configuration.isPressed ? 0.6 : 0.8),
                        in: RoundedRectangle(cornerRadius: Radius.chip))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.chip)
                    .stroke(Color.terracotta.opacity(0.25), lineWidth: 1)
            )
    }
}

// Selectable interest / tag chip (Honey/Apricot accents, .caption medium).
struct InterestChip: View {
    let title: String
    var selected: Bool = false
    var body: some View {
        Text(title)
            .font(.labelSmall)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(selected ? Color.honey : Color.peach,
                        in: Capsule())
            .foregroundStyle(selected ? Color.terracotta : Color.terracotta.opacity(0.7))
            .overlay(
                Capsule().stroke(selected ? Color.terracotta.opacity(0.5) : .clear, lineWidth: 1)
            )
    }
}

// Simple flow layout so interest chips wrap across lines.
struct FlowLayout: Layout {
    var spacing: CGFloat = Spacing.sm

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > maxWidth {
                x = 0; y += rowHeight + spacing; rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth == .infinity ? x : maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX {
                x = bounds.minX; y += rowHeight + spacing; rowHeight = 0
            }
            sub.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
