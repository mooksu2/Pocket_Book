// Extensions/UIView+Extensions.swift
import UIKit

extension UIView {
    /// 누름 → 살짝 줄어드는 스프링 애니메이션
    func pressDown() {
        UIView.animate(withDuration: 0.12, delay: 0, options: [.allowUserInteraction]) {
            self.transform = CGAffineTransform(scaleX: 0.94, y: 0.94)
        }
    }
    func pressUp() {
        UIView.animate(withDuration: 0.3, delay: 0,
                       usingSpringWithDamping: 0.6, initialSpringVelocity: 0.4,
                       options: [.allowUserInteraction]) {
            self.transform = .identity
        }
    }

    /// 아래에서 페이드 인 (셀 등장용)
    func fadeSlideIn(delay: TimeInterval = 0) {
        alpha = 0
        transform = CGAffineTransform(translationX: 0, y: 12)
        UIView.animate(withDuration: 0.4, delay: delay,
                       usingSpringWithDamping: 0.85, initialSpringVelocity: 0.2,
                       options: [.curveEaseOut]) {
            self.alpha = 1
            self.transform = .identity
        }
    }

    func roundCorners(_ radius: CGFloat) {
        layer.cornerRadius = radius
        layer.cornerCurve = .continuous
        clipsToBounds = true
    }
}
