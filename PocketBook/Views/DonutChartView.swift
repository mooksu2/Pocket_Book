// Views/DonutChartView.swift
import UIKit

/// 카테고리별 비중을 보여주는 도넛(링) 차트.
/// 각 세그먼트가 CAShapeLayer로, 시계방향으로 순차적으로 채워진다.
/// 가운데에는 총 지출 금액을 표시한다.
final class DonutChartView: UIView {

    private var segmentLayers: [CAShapeLayer] = []
    private var gradientLayers: [CAGradientLayer] = []
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
    private var needsRedraw = false
    private var lastDrawnSize: CGSize = .zero

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

        // 다크/라이트 전환 시 CALayer 색상을 다시 그린다 (iOS 17 모던 API)
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (v: DonutChartView, _) in
            v.needsRedraw = true
            v.setNeedsLayout()
        }
    }
    required init?(coder: NSCoder) { fatalError() }

    func setData(totals: [Category: Int], total: Int) {
        pending = (totals, total)
        needsRedraw = true
        centerAmount.setValue(total, animated: true)
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let data = pending else { return }
        // 새 데이터가 오거나 크기가 바뀐 경우에만 다시 그린다.
        // 모든 레이아웃 패스마다 다시 그리면, 토글 버튼 상태 변경 같은 무관한
        // 레이아웃 갱신에도 진행 중인 애니메이션이 리셋된다.
        guard needsRedraw || bounds.size != lastDrawnSize else { return }
        needsRedraw = false
        lastDrawnSize = bounds.size
        drawDonut(totals: data.totals, total: data.total)
    }

    private func drawDonut(totals: [Category: Int], total: Int) {
        segmentLayers.forEach { $0.removeFromSuperlayer() }
        segmentLayers.removeAll()
        gradientLayers.forEach { $0.removeFromSuperlayer() }
        gradientLayers.removeAll()
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
        // 조각 사이 흰 틈새 (각도). 조각이 2개 이상일 때만 적용
        let segmentCount = Category.allCases.filter { (totals[$0] ?? 0) > 0 }.count
        let gap: CGFloat = segmentCount > 1 ? (3.0 / radius) : 0   // 약 3px 틈
        for cat in Category.allCases {
            let amount = totals[cat] ?? 0
            guard amount > 0 else { continue }
            let fraction = CGFloat(amount) / CGFloat(total)
            let end = cursor + fraction * 2 * .pi

            // 양 끝을 gap의 절반씩 안으로 좁혀 조각 사이에 배경이 비치게
            let arcLen = end - cursor
            let g = arcLen > gap * 1.5 ? gap : 0
            let path = UIBezierPath(arcCenter: center, radius: radius,
                                    startAngle: cursor + g / 2, endAngle: end - g / 2, clockwise: true)
            let mask = CAShapeLayer()
            mask.path = path.cgPath
            mask.strokeColor = UIColor.black.cgColor
            mask.fillColor = UIColor.clear.cgColor
            mask.lineWidth = lineWidth
            mask.lineCap = .butt   // round는 작은 조각을 뭉개므로 평평하게

            let grad = CAGradientLayer()
            grad.frame = bounds
            grad.colors = cat.gradient.map { $0.cgColor }
            grad.startPoint = CGPoint(x: 0.5, y: 0)
            grad.endPoint = CGPoint(x: 0.5, y: 1)
            grad.mask = mask
            layer.addSublayer(grad)
            segmentLayers.append(mask)
            gradientLayers.append(grad)

            // 순차 채움 애니메이션 (마스크의 strokeEnd)
            let anim = CABasicAnimation(keyPath: "strokeEnd")
            anim.fromValue = 0
            anim.toValue = 1
            anim.duration = 0.5
            anim.beginTime = CACurrentMediaTime() + delay
            anim.timingFunction = CAMediaTimingFunction(name: .easeOut)
            anim.fillMode = .backwards
            mask.add(anim, forKey: "fill")

            cursor = end
            delay += 0.18
        }
    }
}
