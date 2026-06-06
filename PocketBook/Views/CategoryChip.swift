// Views/CategoryChip.swift
import UIKit

/// 입력 화면의 카테고리 선택 칩. 휠 스크롤보다 빠른 1-탭 선택.
final class CategoryChip: UIControl {

    let category: Category
    private let iconView = UIImageView()
    private let label = UILabel()

    override var isSelected: Bool {
        didSet { updateAppearance() }
    }

    init(category: Category) {
        self.category = category
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        roundCorners(Theme.Radius.md)
        layer.borderWidth = 1.5

        iconView.image = UIImage(systemName: category.symbolName)
        iconView.contentMode = .scaleAspectFit
        iconView.preferredSymbolConfiguration = .init(pointSize: 20, weight: .semibold)
        iconView.translatesAutoresizingMaskIntoConstraints = false

        label.text = category.rawValue
        label.font = Theme.Font.caption(13)
        label.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView(arrangedSubviews: [iconView, label])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 4
        stack.isUserInteractionEnabled = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            heightAnchor.constraint(equalToConstant: 64),
        ])
        updateAppearance()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func updateAppearance() {
        if isSelected {
            backgroundColor = category.color
            layer.borderColor = category.color.cgColor
            iconView.tintColor = .white
            label.textColor = .white
            label.font = Theme.Font.title(13)
        } else {
            backgroundColor = .clear
            layer.borderColor = Theme.Color.hairline.cgColor
            iconView.tintColor = category.color
            label.textColor = Theme.Color.subText
            label.font = Theme.Font.caption(13)
        }
    }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.1) {
                self.transform = self.isHighlighted
                    ? CGAffineTransform(scaleX: 0.95, y: 0.95) : .identity
            }
        }
    }
}
