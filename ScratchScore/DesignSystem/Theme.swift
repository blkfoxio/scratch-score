import SwiftUI

/// Central design tokens for Scratch Score. Golf-inspired greens with clear,
/// high-contrast scoring accents (fairway green = good, sand/red = attention).
enum Theme {
    enum Palette {
        static let fairway = Color(red: 0.204, green: 0.616, blue: 0.376)   // primary green
        static let fairwayDark = Color(red: 0.090, green: 0.267, blue: 0.153)
        static let rough = Color(red: 0.298, green: 0.451, blue: 0.298)

        static let good = Color(red: 0.184, green: 0.671, blue: 0.404)      // at/under target
        static let warn = Color(red: 0.851, green: 0.518, blue: 0.176)      // slightly over
        static let bad = Color(red: 0.804, green: 0.278, blue: 0.278)       // over target
    }

    enum Metrics {
        static let cornerRadius: CGFloat = 16
        static let cardPadding: CGFloat = 16
        static let controlHeight: CGFloat = 56
    }
}

/// Exposed on `ShapeStyle where Self == Color` so the `.ssFairway` shorthand works in
/// both `Color` positions (`.tint(.ssFairway)`) and generic `ShapeStyle` positions
/// (`.foregroundStyle(.ssBad)`, `.fill(.ssGood)`). Also accessible as `Color.ssFairway`.
extension ShapeStyle where Self == Color {
    static var ssFairway: Color { Theme.Palette.fairway }
    static var ssFairwayDark: Color { Theme.Palette.fairwayDark }
    static var ssGood: Color { Theme.Palette.good }
    static var ssWarn: Color { Theme.Palette.warn }
    static var ssBad: Color { Theme.Palette.bad }
}
