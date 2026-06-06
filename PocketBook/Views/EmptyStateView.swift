// Views/EmptyStateView.swift
import UIKit

final class EmptyStateView: UIView {
    private let iconView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.tintColor = Theme.Color.tertiaryText
        iv.preferredSymbolConfiguration = .init(pointSize: 48, weight: .light)
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    private let titleLabel: UILabel = {
        let l = UILabel()
        l.font = Theme.Font.title(16)
        l.textColor = Theme.Color.subText
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    private let subtitleLabel: UILabel = {
        let l = UILabel()
        l.font = Theme.Font.body(14)
        l.textColor = Theme.Color.tertiaryText
        l.textAlignment = .center
        l.numberOfLines = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    init(symbol: String, title: String, subtitle: String) {
        super.init(frame: .zero)
        iconView.image = UIImage(systemName: symbol)
        titleLabel.text = title
        subtitleLabel.text = subtitle

        let stack = UIStackView(arrangedSubviews: [iconView, titleLabel, subtitleLabel])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = Theme.Space.md
        stack.setCustomSpacing(Theme.Space.lg, after: iconView)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 40),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -40),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    /// 상태에 따라 아이콘·문구를 교체 (빈 달 ↔ 검색 결과 없음).
    func update(symbol: String, title: String, subtitle: String) {
        iconView.image = UIImage(systemName: symbol)
        titleLabel.text = title
        subtitleLabel.text = subtitle
    }
}
