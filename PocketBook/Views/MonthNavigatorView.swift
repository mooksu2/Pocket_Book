// Views/MonthNavigatorView.swift
import UIKit

/// 월 이동 헤더: ‹ 2026년 6월 › + [오늘] — 기록·캘린더·통계 탭 공용.
final class MonthNavigatorView: UIView {

    var onPrev:     (() -> Void)?
    var onNext:     (() -> Void)?
    var onTapMonth: (() -> Void)?
    var onToday:    (() -> Void)?

    private let monthButton: UIButton = {
        var c = UIButton.Configuration.plain()
        c.baseForegroundColor = Theme.Color.mainText
        c.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12)
        c.image = UIImage(systemName: "chevron.down",
                          withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .bold))
        c.imagePlacement = .trailing
        c.imagePadding = 5
        c.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer {
            var a = $0; a.font = Theme.Font.title(16); return a
        }
        let b = UIButton(configuration: c)
        b.configurationUpdateHandler = { btn in btn.alpha = btn.isHighlighted ? 0.5 : 1 }
        return b
    }()
    private let prevButton = MonthNavigatorView.nav("chevron.left")
    private let nextButton = MonthNavigatorView.nav("chevron.right")
    private let todayButton: UIButton = {
        var c = UIButton.Configuration.plain()
        c.title = "오늘"
        c.baseForegroundColor = Theme.Color.point
        c.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 10, bottom: 5, trailing: 10)
        c.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer {
            var a = $0; a.font = Theme.Font.caption(12); return a
        }
        let b = UIButton(configuration: c)
        b.backgroundColor = Theme.Color.pointSoft
        b.layer.cornerRadius = 12
        b.layer.cornerCurve = .continuous
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    private static func nav(_ symbol: String) -> UIButton {
        var c = UIButton.Configuration.plain()
        c.image = UIImage(systemName: symbol,
                          withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold))
        c.baseForegroundColor = Theme.Color.point
        // 터치 영역 확대 — 화살표 판정이 빡빡하지 않게
        c.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12)
        return UIButton(configuration: c)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        let group = UIStackView(arrangedSubviews: [prevButton, monthButton, nextButton])
        group.alignment = .center
        group.spacing = Theme.Space.sm
        group.translatesAutoresizingMaskIntoConstraints = false
        todayButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(group)
        addSubview(todayButton)
        NSLayoutConstraint.activate([
            group.centerXAnchor.constraint(equalTo: centerXAnchor),
            group.topAnchor.constraint(equalTo: topAnchor),
            group.bottomAnchor.constraint(equalTo: bottomAnchor),
            todayButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Theme.Space.lg),
            todayButton.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        prevButton.addAction(UIAction { [weak self] _ in self?.onPrev?() }, for: .touchUpInside)
        nextButton.addAction(UIAction { [weak self] _ in self?.onNext?() }, for: .touchUpInside)
        monthButton.addAction(UIAction { [weak self] _ in self?.onTapMonth?() }, for: .touchUpInside)
        todayButton.addAction(UIAction { [weak self] _ in self?.onToday?() }, for: .touchUpInside)
    }
    required init?(coder: NSCoder) { fatalError() }

    /// 라벨·오늘 버튼 상태 갱신 (현재 달이면 오늘 버튼 숨김)
    func configure(year: Int, month: Int) {
        monthButton.configuration?.title = "\(year)년 \(month)월"
        let t = Date()
        todayButton.isHidden = (year == t.year && month == t.month)
    }
}
