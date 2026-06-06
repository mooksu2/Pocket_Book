// Views/BarChartView.swift
import UIKit

/// 계획서 명세에 따른 Core Graphics 막대 차트 (draw(_:) 직접 오버라이드).
/// progress(0→1)를 CADisplayLink로 구동해 막대가 자라나는 애니메이션을 구현.
final class BarChartView: UIView {

    private var totals: [Category: Int] = [:]
    private var grandTotal: Int = 1
    private var progress: CGFloat = 0
    private var displayLink: CADisplayLink?
    private var startTime: CFTimeInterval = 0
    private let duration: CFTimeInterval = 0.7

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        contentMode = .redraw
    }
    required init?(coder: NSCoder) { fatalError() }

    func setData(totals: [Category: Int], total: Int) {
        self.totals = totals
        self.grandTotal = max(total, 1)
        animateIn()
    }

    private func animateIn() {
        displayLink?.invalidate()
        progress = 0
        startTime = CACurrentMediaTime()
        let link = CADisplayLink(target: self, selector: #selector(step))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    @objc private func step() {
        let t = min((CACurrentMediaTime() - startTime) / duration, 1)
        progress = CGFloat(1 - pow(1 - t, 3))   // easeOutCubic
        setNeedsDisplay()
        if t >= 1 { displayLink?.invalidate(); displayLink = nil }
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        let cats = Category.allCases
        let rowH = rect.height / CGFloat(cats.count)
        let barH: CGFloat = 22
        let labelW: CGFloat = 52
        let pctW: CGFloat = 44
        let amtH: CGFloat = 15
        let maxBarW = rect.width - labelW - pctW - 12

        for (i, cat) in cats.enumerated() {
            let amount = totals[cat] ?? 0
            let frac = grandTotal > 0 ? CGFloat(amount) / CGFloat(grandTotal) : 0
            let fullW = frac * maxBarW
            let barW = max(fullW * progress, amount > 0 ? 3 : 0)
            let y = CGFloat(i) * rowH + (rowH - barH - amtH - 3) / 2

            // 카테고리명
            (cat.rawValue as NSString).draw(
                in: CGRect(x: 0, y: y + (barH - 17) / 2, width: labelW - 6, height: 17),
                withAttributes: [
                    .font: UIFont.systemFont(ofSize: 14, weight: .semibold),
                    .foregroundColor: cat.color
                ])

            // 배경 트랙
            let bg = UIBezierPath(roundedRect:
                CGRect(x: labelW, y: y, width: maxBarW, height: barH), cornerRadius: barH / 2)
            ctx.setFillColor(cat.color.withAlphaComponent(0.12).cgColor)
            bg.fill()

            // 채움 막대 (그라데이션)
            if barW > 0 {
                ctx.saveGState()
                let fillRect = CGRect(x: labelW, y: y, width: barW, height: barH)
                let clip = UIBezierPath(roundedRect: fillRect, cornerRadius: barH / 2)
                clip.addClip()
                let colors = cat.gradient.map { $0.cgColor } as CFArray
                if let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                         colors: colors, locations: [0, 1]) {
                    ctx.drawLinearGradient(grad,
                        start: CGPoint(x: labelW, y: 0),
                        end: CGPoint(x: labelW + maxBarW, y: 0),
                        options: [])
                }
                ctx.restoreGState()
            }

            // 퍼센트
            ("\(Int(frac * 100))%" as NSString).draw(
                in: CGRect(x: rect.width - pctW, y: y + (barH - 16) / 2, width: pctW, height: 16),
                withAttributes: [
                    .font: UIFont.monospacedDigitSystemFont(ofSize: 13, weight: .bold),
                    .foregroundColor: cat.color
                ])

            // 금액
            (amount.won as NSString).draw(
                in: CGRect(x: labelW, y: y + barH + 2, width: maxBarW, height: amtH),
                withAttributes: [
                    .font: UIFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular),
                    .foregroundColor: Theme.Color.subText
                ])
        }
    }

    deinit { displayLink?.invalidate() }
}
