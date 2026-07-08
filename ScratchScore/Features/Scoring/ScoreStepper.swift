import SwiftUI

/// A large tap-target stepper for entering a hole's row values without a keyboard.
/// `value` is optional so an untouched row reads as "–".
struct ScoreStepper: View {
    let title: String
    let systemImage: String
    @Binding var value: Int?
    var range: ClosedRange<Int> = 0...12
    var defaultOnFirstTap: Int = 1
    var valueTint: (Int?) -> Color = { _ in .primary }
    var onChange: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.medium))
                .labelStyle(.titleAndIcon)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 0) {
                stepButton(systemName: "minus") { decrement() }
                Text(display)
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(valueTint(value))
                    .frame(width: 56)
                    .contentTransition(.numericText())
                stepButton(systemName: "plus") { increment() }
            }
            .background(.background.secondary, in: Capsule())
        }
    }

    private var display: String { value.map(String.init) ?? "–" }

    private func stepButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.headline)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.ssFairway)
    }

    private func increment() {
        let next = min((value ?? (defaultOnFirstTap - 1)) + 1, range.upperBound)
        setValue(next)
    }

    private func decrement() {
        guard let current = value else { return }
        if current <= range.lowerBound {
            setValue(nil)
        } else {
            setValue(current - 1)
        }
    }

    private func setValue(_ newValue: Int?) {
        withAnimation(.snappy(duration: 0.15)) { value = newValue }
        Haptics.tap()
        onChange()
    }
}

enum Haptics {
    static func tap() {
        #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        #endif
    }
    static func success() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }
}
