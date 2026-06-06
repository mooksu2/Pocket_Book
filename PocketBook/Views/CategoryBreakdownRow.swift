// Views/CategoryBreakdownRow.swift
import UIKit

/// 통계 화면 하단 — 카테고리별 금액 + 미니 진행바
final class CategoryBreakdownRow: UIView {
    private let dot = UIView()
    private let nameLabel = UILabel()
    private let amountLabel = UILabel()
    private let pctLabel = UILabel()

    init(category: Category, amount: Int, fraction: CGFloat) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

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

        addSubview(dot)
        addSubview(nameLabel)
        addSubview(pctLabel)
        addSubview(amountLabel)
        NSLayoutConstraint.activate([
            dot.leadingAnchor.constraint(equalTo: leadingAnchor),
            dot.centerYAnchor.constraint(equalTo: centerYAnchor),
            dot.widthAnchor.constraint(equalToConstant: 8),
            dot.heightAnchor.constraint(equalToConstant: 8),

            nameLabel.leadingAnchor.constraint(equalTo: dot.trailingAnchor, constant: 8),
            nameLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            pctLabel.leadingAnchor.constraint(equalTo: nameLabel.trailingAnchor, constant: 6),
            pctLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            amountLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            amountLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            heightAnchor.constraint(equalToConstant: 36),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }
}
