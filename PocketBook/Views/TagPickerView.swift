import UIKit

/// 카테고리별 태그 선택 뷰 (가로 스크롤 알약 + 고정비 토글)
final class TagPickerView: UIView {

    var onChanged: (([String], Bool) -> Void)?
    private(set) var selectedTags: Set<String> = []
    private(set) var isFixed: Bool = false

    private let scroll      = UIScrollView()
    private let pillStack   = UIStackView()
    private let fixedSwitch = UISwitch()
    private var category: Category = .food

    override init(frame: CGRect) {
        super.init(frame: frame)
        scroll.showsHorizontalScrollIndicator = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        pillStack.axis    = .horizontal
        pillStack.spacing = 8
        pillStack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(pillStack)

        let fixedLabel = UILabel()
        fixedLabel.text      = "고정비"
        fixedLabel.font      = Theme.Font.body(14)
        fixedLabel.textColor = Theme.Color.mainText
        fixedSwitch.onTintColor = Theme.Color.point
        fixedSwitch.addTarget(self, action: #selector(fixedToggled), for: .valueChanged)

        let fixedRow = UIStackView(arrangedSubviews: [fixedLabel, UIView(), fixedSwitch])
        fixedRow.axis = .horizontal
        fixedRow.translatesAutoresizingMaskIntoConstraints = false

        let outer = UIStackView(arrangedSubviews: [scroll, fixedRow])
        outer.axis    = .vertical
        outer.spacing = 10
        outer.translatesAutoresizingMaskIntoConstraints = false
        addSubview(outer)

        NSLayoutConstraint.activate([
            outer.topAnchor.constraint(equalTo: topAnchor),
            outer.bottomAnchor.constraint(equalTo: bottomAnchor),
            outer.leadingAnchor.constraint(equalTo: leadingAnchor),
            outer.trailingAnchor.constraint(equalTo: trailingAnchor),
            scroll.heightAnchor.constraint(equalToConstant: 34),
            pillStack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            pillStack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            pillStack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            pillStack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            pillStack.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    func configure(for category: Category, preselected: [String] = [], isFixed: Bool = false) {
        self.category     = category
        self.selectedTags = Set(preselected)
        self.isFixed      = isFixed
        fixedSwitch.isOn  = isFixed
        rebuild()
    }

    private func rebuild() {
        pillStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let frequent = TagLibrary.frequent(for: category)
        let presets  = (TagLibrary.presets[category] ?? []).filter { !frequent.contains($0) }
        (frequent + presets).forEach { addPill($0) }
    }

    private func addPill(_ tag: String) {
        let b = UIButton(type: .system)
        b.setTitle(tag, for: .normal)
        b.titleLabel?.font = Theme.Font.caption(13)
        b.contentEdgeInsets = UIEdgeInsets(top: 0, left: 14, bottom: 0, right: 14)
        b.layer.cornerRadius = 16
        b.layer.cornerCurve  = .continuous
        b.layer.borderWidth  = 1
        b.addAction(UIAction { [weak self] _ in self?.toggle(tag, button: b) }, for: .touchUpInside)
        style(b, selected: selectedTags.contains(tag))
        pillStack.addArrangedSubview(b)
    }

    private func toggle(_ tag: String, button: UIButton) {
        Haptic.selection()
        if selectedTags.contains(tag) { selectedTags.remove(tag) } else { selectedTags.insert(tag) }
        style(button, selected: selectedTags.contains(tag))
        onChanged?(Array(selectedTags), isFixed)
    }

    private func style(_ b: UIButton, selected: Bool) {
        b.backgroundColor = selected ? category.color : .clear
        b.setTitleColor(selected ? .white : Theme.Color.subText, for: .normal)
        b.layer.borderColor = selected ? category.color.cgColor : Theme.Color.hairline.cgColor
    }

    @objc private func fixedToggled(_ sw: UISwitch) {
        isFixed = sw.isOn
        onChanged?(Array(selectedTags), isFixed)
    }
}
