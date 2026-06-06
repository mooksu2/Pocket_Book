// Views/DonutChartView.swift
import UIKit

/// 카테고리별 비중을 보여주는 도넛(링) 차트.
/// 각 세그먼트가 CAShapeLayer로, 시계방향으로 순차적으로 채워진다.
/// 가운데에는 총 지출 금액을 표시한다.
final class DonutChartView: UIView {

    private var segmentLayers: [CAShapeLayer] = []
    private let trackLayer = CAShapeLayer()

    private let centerTitle: UILabel = {
        let l = UILabel()
        l.text = "총 지출"
        l.font = Theme.Font.caption(12)
        l.textColor = Theme.Color.subText
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    private let centerAmount: AnimatedCountLabel = {
        let l = AnimatedCountLabel()
        l.font = Theme.Font.money(26, .heavy)
        l.textColor = Theme.Color.mainText
        l.textAlignment = .center
        l.adjustsFontSizeToFitWidth = true
        l.minimumScaleFactor = 0.6
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private var pending: (totals: [Category: Int], total: Int)?

    private let lineWidth: CGFloat = 26

    override init(frame: CGRect) {
        super.init(frame: frame)
        let stack = UIStackView(arrangedSubviews: [centerTitle, centerAmount])
        stack.axis = .vertical
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, multiplier: 0.6),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    func setData(totals: [Category: Int], total: Int) {
        pending = (totals, total)
        centerAmount.setValue(total, animated: true)
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let data = pending else { return }
        drawDonut(totals: data.totals, total: data.total)
    }

    private func drawDonut(totals: [Category: Int], total: Int) {
        segmentLayers.forEach { $0.removeFromSuperlayer() }
        segmentLayers.removeAll()
        trackLayer.removeFromSuperlayer()

        let radius = (min(bounds.width, bounds.height) - lineWidth) / 2
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let start = -CGFloat.pi / 2   // 12시 방향

        // 트랙(배경 링)
        let trackPath = UIBezierPath(arcCenter: center, radius: radius,
                                     startAngle: 0, endAngle: 2 * .pi, clockwise: true)
        trackLayer.path = trackPath.cgPath
        trackLayer.strokeColor = Theme.Color.hairline.cgColor
        trackLayer.fillColor = UIColor.clear.cgColor
        trackLayer.lineWidth = lineWidth
        layer.insertSublayer(trackLayer, at: 0)

        guard total > 0 else { return }

        var cursor = start
        var delay: CFTimeInterval = 0
        for cat in Category.allCases {
            let amount = totals[cat] ?? 0
            guard amount > 0 else { continue }
            let fraction = CGFloat(amount) / CGFloat(total)
            let end = cursor + fraction * 2 * .pi

            let path = UIBezierPath(arcCenter: center, radius: radius,
                                    startAngle: cursor, endAngle: end, clockwise: true)
            let seg = CAShapeLayer()
            seg.path = path.cgPath
            seg.strokeColor = cat.color.cgColor
            seg.fillColor = UIColor.clear.cgColor
            seg.lineWidth = lineWidth
            seg.lineCap = .round
            layer.addSublayer(seg)
            segmentLayers.append(seg)

            // 순차 채움 애니메이션
            let anim = CABasicAnimation(keyPath: "strokeEnd")
            anim.fromValue = 0
            anim.toValue = 1
            anim.duration = 0.5
            anim.beginTime = CACurrentMediaTime() + delay
            anim.timingFunction = CAMediaTimingFunction(name: .easeOut)
            anim.fillMode = .backwards
            seg.add(anim, forKey: "fill")

            cursor = end
            delay += 0.18
        }
    }
}
