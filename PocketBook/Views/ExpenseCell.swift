// Views/ExpenseCell.swift
import UIKit

final class ExpenseCell: UITableViewCell {
    static let reuseID = "ExpenseCell"

    private let iconContainer: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.roundCorners(Theme.Radius.md)
        return v
    }()
    private let iconView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.tintColor = .white
        iv.preferredSymbolConfiguration = .init(pointSize: 16, weight: .semibold)
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    private let categoryLabel: UILabel = {
        let l = UILabel()
        l.font = Theme.Font.title(15)
        l.textColor = Theme.Color.mainText
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    private let memoLabel: UILabel = {
        let l = UILabel()
        l.font = Theme.Font.body(13)
        l.textColor = Theme.Color.subText
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    private let tagStack: UIStackView = {
        let s = UIStackView()
        s.axis = .horizontal
        s.spacing = 4
        s.alignment = .center
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()
    private let amountLabel: UILabel = {
        let l = UILabel()
        l.font = Theme.Font.money(17, .bold)
        l.textColor = Theme.Color.mainText
        l.textAlignment = .right
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    private let timeLabel: UILabel = {
        let l = UILabel()
        l.font = Theme.Font.caption(11)
        l.textColor = Theme.Color.tertiaryText
        l.textAlignment = .right
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        iconContainer.addSubview(iconView)

        let titleStack = UIStackView(arrangedSubviews: [categoryLabel, memoLabel, tagStack])
        titleStack.axis = .vertical
        titleStack.spacing = 3
        titleStack.alignment = .leading
        titleStack.translatesAutoresizingMaskIntoConstraints = false

        let amountStack = UIStackView(arrangedSubviews: [amountLabel, timeLabel])
        amountStack.axis = .vertical
        amountStack.alignment = .trailing
        amountStack.spacing = 2
        amountStack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(iconContainer)
        contentView.addSubview(titleStack)
        contentView.addSubview(amountStack)

        NSLayoutConstraint.activate([
            iconContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Theme.Space.lg),
            iconContainer.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconContainer.widthAnchor.constraint(equalToConstant: 40),
            iconContainer.heightAnchor.constraint(equalToConstant: 40),

            iconView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),

            titleStack.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: Theme.Space.md),
            titleStack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            titleStack.trailingAnchor.constraint(lessThanOrEqualTo: amountStack.leadingAnchor, constant: -Theme.Space.sm),

            amountStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Theme.Space.lg),
            amountStack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 68),
        ])
    }

    func configure(with e: Expense) {
        iconContainer.backgroundColor = e.category.color
        iconView.image = UIImage(systemName: e.category.symbolName)
        categoryLabel.text = e.category.rawValue
        memoLabel.text = e.memo.isEmpty ? "메모 없음" : e.memo
        memoLabel.textColor = e.memo.isEmpty ? Theme.Color.tertiaryText : Theme.Color.subText

        // 태그 알약 다시 그리기
        tagStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        if e.isFixed {
            tagStack.addArrangedSubview(makeChip("고정비", color: Theme.Color.point, filled: true))
        }
        for tag in e.tags {
            tagStack.addArrangedSubview(makeChip(tag, color: e.category.color, filled: false))
        }
        tagStack.isHidden = e.tags.isEmpty && !e.isFixed
        if !tagStack.isHidden {
            let spacer = UIView()
            spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
            tagStack.addArrangedSubview(spacer)   // 왼쪽 정렬 + 늘어남 방지
        }

        amountLabel.text = "-" + e.amount.won
        timeLabel.text = e.date.timeShort
    }

    private func makeChip(_ text: String, color: UIColor, filled: Bool) -> UIView {
        let l = TagPillLabel()
        l.text = text
        l.font = Theme.Font.caption(11)
        l.textColor = filled ? .white : color
        l.backgroundColor = filled ? color : color.withAlphaComponent(0.15)
        l.layer.cornerRadius = 9
        l.layer.masksToBounds = true
        l.translatesAutoresizingMaskIntoConstraints = false
        l.setContentHuggingPriority(.required, for: .horizontal)
        return l
    }
}

/// 내부 여백을 가진 알약형 라벨
final class TagPillLabel: UILabel {
    var inset = UIEdgeInsets(top: 2, left: 8, bottom: 2, right: 8)
    override func drawText(in rect: CGRect) { super.drawText(in: rect.inset(by: inset)) }
    override var intrinsicContentSize: CGSize {
        let s = super.intrinsicContentSize
        return CGSize(width: s.width + inset.left + inset.right,
                      height: s.height + inset.top + inset.bottom)
    }
}
