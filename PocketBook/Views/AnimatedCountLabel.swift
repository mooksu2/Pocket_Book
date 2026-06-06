// Views/AnimatedCountLabel.swift
import UIKit

/// 0 → 목표 금액까지 부드럽게 카운트업되는 라벨 (₩ 접두)
final class AnimatedCountLabel: UILabel {

    private var displayLink: CADisplayLink?
    private var startValue = 0
    private var endValue = 0
    private var startTime: CFTimeInterval = 0
    private let duration: CFTimeInterval = 0.7

    func setValue(_ value: Int, animated: Bool = true) {
        displayLink?.invalidate()
        guard animated else {
            text = value.won
            endValue = value
            return
        }
        startValue = endValue
        endValue   = value
        startTime  = CACurrentMediaTime()
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    @objc private func tick() {
        let now = CACurrentMediaTime()
        let t = min((now - startTime) / duration, 1)
        // easeOutCubic
        let eased = 1 - pow(1 - t, 3)
        let current = startValue + Int(Double(endValue - startValue) * eased)
        text = current.won
        if t >= 1 {
            text = endValue.won
            displayLink?.invalidate()
            displayLink = nil
        }
    }

    deinit { displayLink?.invalidate() }
}
