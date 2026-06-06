// Views/SectionHeaderView.swift
import UIKit

/// 날짜별 섹션 헤더 — 좌측 날짜, 우측 당일 합계
final class SectionHeaderView: UIView {
    private let dateLabel: UILabel = {
        let l = UILabel()
        l.font = Theme.Font.title(14)
        l.textColor = Theme.Color.mainText
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    private let totalLabel: UILabel = {
        let l = UILabel()
        l.font = Theme.Font.money(13, .semibold)
        l.textColor = Theme.Color.subText
        l.textAlignment = .right
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Theme.Color.background
        addSubview(dateLabel)
        addSubview(totalLabel)
        NSLayoutConstraint.activate([
            dateLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Theme.Space.lg),
            dateLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            totalLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Theme.Space.lg),
            totalLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    func configure(date: Date, total: Int) {
        dateLabel.text = date.sectionTitle
        totalLabel.text = total.won
    }
}
