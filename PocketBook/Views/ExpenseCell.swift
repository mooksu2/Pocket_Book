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
        // insetGrouped 카드 표면을 card 토큰(흰색)으로 명시 + 헤더 카드와 같은 곡률
        var bg = UIBackgroundConfiguration.listGroupedCell()
        bg.backgroundColor = Theme.Color.card
        bg.cornerRadius = Theme.Radius.lg   // 20 — 위쪽 헤더 카드와 동일
        backgroundConfiguration = bg
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

            contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 74),
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
        if e.recurringID != nil || e.isFixed {
            tagStack.addArrangedSubview(makeFixedChip())
        }
        for tag in e.tags {
            tagStack.addArrangedSubview(makeChip(tag, color: e.category.color, filled: false))
        }
        let isFixedRow = (e.recurringID != nil || e.isFixed)
        tagStack.isHidden = e.tags.isEmpty && !isFixedRow
        if !tagStack.isHidden {
            let spacer = UIView()
            spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
            tagStack.addArrangedSubview(spacer)   // 왼쪽 정렬 + 늘어남 방지
        }

        amountLabel.text = "-" + e.amount.won
        timeLabel.text = e.date.timeShort
    }

    /// 고정지출 전용 칩 — 🔄 아이콘 + "고정" 텍스트로 일반 지출과 명확히 구분
    private func makeFixedChip() -> UIView {
        let container = UIView()
        container.backgroundColor = Theme.Color.pointSoft
        container.layer.cornerRadius = 9
        container.layer.masksToBounds = true
        container.translatesAutoresizingMaskIntoConstraints = false

        let icon = UIImageView(image: UIImage(systemName: "arrow.triangle.2.circlepath"))
        icon.tintColor = Theme.Color.point
        icon.contentMode = .scaleAspectFit
        icon.preferredSymbolConfiguration = .init(pointSize: 9, weight: .bold)
        icon.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text = "고정"
        label.font = Theme.Font.caption(11)
        label.textColor = Theme.Color.point
        label.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(icon)
        container.addSubview(label)
        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 7),
            icon.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 10),
            icon.heightAnchor.constraint(equalToConstant: 10),
            label.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 3),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 2),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -2),
        ])
        container.setContentHuggingPriority(.required, for: .horizontal)
        return container
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
