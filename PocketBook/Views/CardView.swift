// Views/CardView.swift
import UIKit

/// 흰 카드 — 연속 곡률 + 그림자 + shadowPath(오프스크린 렌더 비용 제거).
/// (헤더·차트·폼 카드 등 크기가 자주 안 바뀌는 카드에 사용)
final class CardView: UIView {

    init(radius: CGFloat = Theme.Radius.lg,
         shadowOpacity: Float = 0.05,
         shadowRadius: CGFloat = 16,
         shadowY: CGFloat = 4) {
        super.init(frame: .zero)
        backgroundColor = Theme.Color.card
        layer.cornerRadius = radius
        layer.cornerCurve = .continuous
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = shadowOpacity
        layer.shadowOffset = CGSize(width: 0, height: shadowY)
        layer.shadowRadius = shadowRadius
        translatesAutoresizingMaskIntoConstraints = false
    }
    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        // 그림자 경로 고정 — 알파 채널 기반 매 프레임 계산 제거
        layer.shadowPath = UIBezierPath(roundedRect: bounds,
                                        cornerRadius: layer.cornerRadius).cgPath
        // 다크모드 전환 시 cgColor 갱신
        layer.shadowColor = UIColor.black.cgColor
    }
}
