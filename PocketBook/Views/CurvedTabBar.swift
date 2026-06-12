// Views/CurvedTabBar.swift
import UIKit

/// UITabBar를 대체하며, 탭 선택을 onSelect로 알린다.
final class CurvedTabBar: UIView {

    struct Item {
        let title: String
        let symbol: String          // 미선택 (윤곽선)
        let selectedSymbol: String  // 선택 (채워짐)
    }

    /// 탭이 선택될 때 호출 (같은 탭 재선택도 전달)
    var onSelect: ((Int) -> Void)?

    private(set) var selectedIndex = 0
    private let items: [Item]
    private var buttons: [TabButton] = []

    /// 곡선 + 그림자를 그리는 배경 레이어
    private let shapeLayer = CAShapeLayer()

    /// 탭바 전체 높이 (콘텐츠 영역 + 홈 인디케이터 여백 포함은 외부에서)
    static let barHeight: CGFloat = 50

    init(items: [Item]) {
        self.items = items
        super.init(frame: .zero)
        backgroundColor = .clear
        layer.addSublayer(shapeLayer)
        shapeLayer.fillColor = Theme.Color.card.cgColor
        shapeLayer.shadowColor = UIColor.black.cgColor
        shapeLayer.shadowOpacity = 0.07
        shapeLayer.shadowRadius = 12
        shapeLayer.shadowOffset = CGSize(width: 0, height: -3)

        let stack = UIStackView()
        stack.distribution = .fillEqually
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        for (i, item) in items.enumerated() {
            let b = TabButton(item: item)
            b.tag = i
            b.isSelectedTab = (i == 0)
            b.addAction(UIAction { [weak self] _ in self?.select(i, animated: true, notify: true) },
                        for: .touchUpInside)
            buttons.append(b)
            stack.addArrangedSubview(b)
        }
    }
    required init?(coder: NSCoder) { fatalError() }

    /// 프로그래매틱 선택 (애니메이션·통지 옵션)
    func select(_ index: Int, animated: Bool, notify: Bool) {
        guard index >= 0, index < buttons.count else { return }
        let changed = index != selectedIndex
        selectedIndex = index
        for (i, b) in buttons.enumerated() {
            b.setSelected(i == index, animated: animated && i == index && changed)
        }
        if notify { onSelect?(index) }
    }

    // 곡선은 매 레이아웃마다 현재 너비에 맞춰 다시 그린다
    override func layoutSubviews() {
        super.layoutSubviews()
        shapeLayer.frame = bounds
        shapeLayer.path = curvedPath(in: bounds).cgPath
        shapeLayer.fillColor = Theme.Color.card.cgColor   // 다크모드 전환 대응
    }

    /// 양 끝 모서리만 둥근 평평한 상단 (B안)
    private func curvedPath(in rect: CGRect) -> UIBezierPath {
        let w = rect.width, h = rect.height
        let corner: CGFloat = 36        // 좌우 상단 라운드 (곡률 강조)
        let p = UIBezierPath()
        p.move(to: CGPoint(x: 0, y: corner))
        p.addQuadCurve(to: CGPoint(x: corner, y: 0),
                       controlPoint: CGPoint(x: 0, y: 0))
        p.addLine(to: CGPoint(x: w - corner, y: 0))
        p.addQuadCurve(to: CGPoint(x: w, y: corner),
                       controlPoint: CGPoint(x: w, y: 0))
        p.addLine(to: CGPoint(x: w, y: h))
        p.addLine(to: CGPoint(x: 0, y: h))
        p.close()
        return p
    }
}

// MARK: - 개별 탭 버튼
private final class TabButton: UIControl {
    private let item: CurvedTabBar.Item
    private let iconView = UIImageView()
    private let titleLabel = UILabel()

    var isSelectedTab = false { didSet { applyStyle(animated: false) } }

    init(item: CurvedTabBar.Item) {
        self.item = item
        super.init(frame: .zero)

        iconView.contentMode = .center
        iconView.preferredSymbolConfiguration = .init(pointSize: 22, weight: .regular)
        iconView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = item.title
        titleLabel.font = Theme.Font.caption(11)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView(arrangedSubviews: [iconView, titleLabel])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 4
        stack.isUserInteractionEnabled = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            iconView.heightAnchor.constraint(equalToConstant: 26),
        ])
        applyStyle(animated: false)
    }
    required init?(coder: NSCoder) { fatalError() }

    func setSelected(_ selected: Bool, animated: Bool) {
        isSelectedTab = selected
        if animated { bounce() }
    }

    private func applyStyle(animated: Bool) {
        let color = isSelectedTab ? Theme.Color.point : Theme.Color.mainText.withAlphaComponent(0.8)
        iconView.image = UIImage(systemName: isSelectedTab ? item.selectedSymbol : item.symbol)
        iconView.preferredSymbolConfiguration = .init(
            pointSize: 22, weight: isSelectedTab ? .semibold : .regular)
        iconView.tintColor = color
        titleLabel.font = isSelectedTab ? Theme.Font.title(11) : Theme.Font.caption(11)
        titleLabel.textColor = color
    }

    /// 선택 시 살짝 튕기는 피드백
    private func bounce() {
        Haptic.selection()
        let anim = CAKeyframeAnimation(keyPath: "transform.scale")
        anim.values = [1.0, 0.84, 1.18, 1.0]
        anim.keyTimes = [0, 0.25, 0.6, 1]
        anim.duration = 0.42
        anim.timingFunction = CAMediaTimingFunction(name: .easeOut)
        iconView.layer.add(anim, forKey: "bounce")
    }

    // 탭 누를 때 살짝 눌리는 피드백
    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.1) {
                self.alpha = self.isHighlighted ? 0.6 : 1
            }
        }
    }
}
