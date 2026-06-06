// Views/CategoryFilterBar.swift
import UIKit

/// 가로 스크롤 카테고리 필터바. "전체" + 4개 카테고리 알약 버튼.
/// 선택된 항목만 채워지고, 콜백으로 선택값(nil = 전체)을 전달.
final class CategoryFilterBar: UIView {

    var onSelect: ((Category?) -> Void)?
    private var selected: Category?            // nil = 전체
    private var pills: [(cat: Category?, button: UIButton)] = []

    private let scroll: UIScrollView = {
        let s = UIScrollView()
        s.showsHorizontalScrollIndicator = false
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()
    private let stack: UIStackView = {
        let s = UIStackView()
        s.axis = .horizontal
        s.spacing = Theme.Space.sm
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(scroll)
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: topAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor),

            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: Theme.Space.lg),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -Theme.Space.lg),
            stack.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor),
        ])

        addPill(title: "전체", cat: nil)
        for cat in Category.allCases { addPill(title: cat.rawValue, cat: cat) }
        refresh()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func addPill(title: String, cat: Category?) {
        let b = UIButton(type: .system)
        b.setTitle(title, for: .normal)
        b.titleLabel?.font = Theme.Font.caption(13)
        b.contentEdgeInsets = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        b.layer.cornerRadius = 18
        b.layer.cornerCurve = .continuous
        b.layer.borderWidth = 1
        b.addAction(UIAction { [weak self] _ in self?.tap(cat) }, for: .touchUpInside)
        pills.append((cat, b))
        stack.addArrangedSubview(b)
    }

    private func tap(_ cat: Category?) {
        guard selected != cat else { return }
        Haptic.selection()
        selected = cat
        refresh()
        onSelect?(cat)
    }

    private func refresh() {
        for (cat, b) in pills {
            let isOn = (cat == selected)
            let tint = cat?.color ?? Theme.Color.point
            if isOn {
                b.backgroundColor = tint
                b.tintColor = .white
                b.setTitleColor(.white, for: .normal)
                b.layer.borderColor = tint.cgColor
            } else {
                b.backgroundColor = .clear
                b.tintColor = Theme.Color.subText
                b.setTitleColor(Theme.Color.subText, for: .normal)
                b.layer.borderColor = Theme.Color.hairline.cgColor
            }
        }
    }
}
