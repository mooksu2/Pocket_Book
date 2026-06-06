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

        let titleStack = UIStackView(arrangedSubviews: [categoryLabel, memoLabel])
        titleStack.axis = .vertical
        titleStack.spacing = 2
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

            contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 64),
        ])
    }

    func configure(with e: Expense) {
        iconContainer.backgroundColor = e.category.color
        iconView.image = UIImage(systemName: e.category.symbolName)
        categoryLabel.text = e.category.rawValue
        memoLabel.text = e.memo.isEmpty ? "메모 없음" : e.memo
        memoLabel.textColor = e.memo.isEmpty ? Theme.Color.tertiaryText : Theme.Color.subText
        amountLabel.text = "-" + e.amount.won
        timeLabel.text = e.date.timeShort
    }
}
