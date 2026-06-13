// DesignSystem/Theme.swift
import UIKit

// MARK: - Design Tokens
enum Theme {

    // ── Colors (다크모드 자동 대응) ──────────────────────────
    enum Color {
        static let point     = UIColor(hex: "#4A7AFF")
        static let pointSoft = UIColor(hex: "#4A7AFF").withAlphaComponent(0.12)

        static let background = UIColor { $0.userInterfaceStyle == .dark
            ? UIColor(hex: "#0F1115") : UIColor(hex: "#F1F3F5") }   // 카드(흰색)와 구분되는 회색 캔버스
        static let card       = UIColor { $0.userInterfaceStyle == .dark
                                  ? UIColor(hex: "#1C1C1E") : .white }
        static let groupedBG  = UIColor { $0.userInterfaceStyle == .dark
            ? UIColor(hex: "#2A2D34") : UIColor(hex: "#F2F4F6") }

        static let mainText     = UIColor.label
        static let subText      = UIColor.secondaryLabel
        static let tertiaryText = UIColor.tertiaryLabel

        static let separator = UIColor.separator
        static let hairline  = UIColor.opaqueSeparator.withAlphaComponent(0.4)
    }

    // ── Spacing ──────────────────────────────────────────────
    enum Space {
        static let xs:  CGFloat = 4
        static let sm:  CGFloat = 8
        static let md:  CGFloat = 12
        static let lg:  CGFloat = 16
        static let xl:  CGFloat = 24
        static let xxl: CGFloat = 32
    }

    // ── Corner Radius ────────────────────────────────────────
    enum Radius {
        static let sm:   CGFloat = 10
        static let md:   CGFloat = 16
        static let lg:   CGFloat = 22
        static let pill: CGFloat = 999
    }

    // ── Typography ───────────────────────────────────────────
    enum Font {
        static func display(_ size: CGFloat = 40) -> UIFont {
            .systemFont(ofSize: size, weight: .heavy)
        }
        static func money(_ size: CGFloat, _ weight: UIFont.Weight = .bold) -> UIFont {
            .monospacedDigitSystemFont(ofSize: size, weight: weight)
        }
        static func title(_ size: CGFloat = 17) -> UIFont {
            .systemFont(ofSize: size, weight: .semibold)
        }
        static func body(_ size: CGFloat = 15) -> UIFont {
            .systemFont(ofSize: size, weight: .regular)
        }
        static func caption(_ size: CGFloat = 12) -> UIFont {
            .systemFont(ofSize: size, weight: .medium)
        }
    }

    // ── Shadow ───────────────────────────────────────────────
    static func applyCardShadow(to layer: CALayer,
                                opacity: Float = 0.08,
                                radius: CGFloat = 14,
                                y: CGFloat = 6) {
        layer.shadowColor   = UIColor.black.cgColor
        layer.shadowOpacity = opacity
        layer.shadowOffset  = CGSize(width: 0, height: y)
        layer.shadowRadius  = radius
    }
}

// MARK: - Haptics
enum Haptic {
    static func selection() { UISelectionFeedbackGenerator().selectionChanged() }
    static func light()     { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func medium()    { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func success()   { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning()   { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
}
