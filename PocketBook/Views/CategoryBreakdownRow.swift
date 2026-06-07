// Views/CategoryBreakdownRow.swift
import UIKit

/// 통계 화면 — 카테고리별 금액 행. 탭하면 펼쳐져서 태그별 내역이 열림.
final class CategoryBreakdownRow: UIView {
    let category: Category
    var onTap: (() -> Void)?

    private let dot = UIView()
    private let nameLabel = UILabel()
    private let amountLabel = UILabel()
    private let pctLabel = UILabel()
    private let chevron = UIImageView()

    init(category: Category, amount: Int, fraction: CGFloat) {
        self.category = category
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        isUserInteractionEnabled = true
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped)))

        dot.backgroundColor = category.color
        dot.roundCorners(4)
        dot.translatesAutoresizingMaskIntoConstraints = false

        nameLabel.text = category.rawValue
        nameLabel.font = Theme.Font.body(15)
        nameLabel.textColor = Theme.Color.mainText
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        pctLabel.text = "\(Int(fraction * 100))%"
        pctLabel.font = Theme.Font.caption(12)
        pctLabel.textColor = Theme.Color.subText
        pctLabel.translatesAutoresizingMaskIntoConstraints = false

        amountLabel.text = amount.won
        amountLabel.font = Theme.Font.money(15, .semibold)
        amountLabel.textColor = Theme.Color.mainText
        amountLabel.textAlignment = .right
        amountLabel.translatesAutoresizingMaskIntoConstraints = false

        chevron.image = UIImage(systemName: "chevron.down",
                                withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .semibold))
        chevron.tintColor = Theme.Color.tertiaryText
        chevron.translatesAutoresizingMaskIntoConstraints = false

        [dot, nameLabel, pctLabel, amountLabel, chevron].forEach { addSubview($0) }
        NSLayoutConstraint.activate([
            dot.leadingAnchor.constraint(equalTo: leadingAnchor),
            dot.centerYAnchor.constraint(equalTo: centerYAnchor),
            dot.widthAnchor.constraint(equalToConstant: 8),
            dot.heightAnchor.constraint(equalToConstant: 8),

            nameLabel.leadingAnchor.constraint(equalTo: dot.trailingAnchor, constant: 8),
            nameLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            pctLabel.leadingAnchor.constraint(equalTo: nameLabel.trailingAnchor, constant: 6),
            pctLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            chevron.trailingAnchor.constraint(equalTo: trailingAnchor),
            chevron.centerYAnchor.constraint(equalTo: centerYAnchor),

            amountLabel.trailingAnchor.constraint(equalTo: chevron.leadingAnchor, constant: -8),
            amountLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            heightAnchor.constraint(equalToConstant: 40),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    func setExpanded(_ expanded: Bool) {
        let name = expanded ? "chevron.up" : "chevron.down"
        chevron.image = UIImage(systemName: name,
                                withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .semibold))
    }

    @objc private func tapped() {
        Haptic.selection()
        onTap?()
    }
}
