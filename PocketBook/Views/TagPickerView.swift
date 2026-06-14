import UIKit

/// 카테고리별 태그 선택 뷰 (가로 스크롤 알약).
/// 고정지출 토글은 옵션 카드로 분리되어 여기선 태그만 다룬다.
final class TagPickerView: UIView {

    var onChanged: (([String]) -> Void)?
    private(set) var selectedTags: Set<String> = []

    private let scroll    = UIScrollView()
    private let pillStack = UIStackView()
    private var category: Category = .food

    override init(frame: CGRect) {
        super.init(frame: frame)
        scroll.showsHorizontalScrollIndicator = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        pillStack.axis    = .horizontal
        pillStack.spacing = 6
        pillStack.distribution = .fill          // 각 칩은 자기 글자 수만큼만 (균등 분배 아님)
        pillStack.alignment = .center
        pillStack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(pillStack)
        addSubview(scroll)

        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: topAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            scroll.heightAnchor.constraint(equalToConstant: 34),
            pillStack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            pillStack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            pillStack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            pillStack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            pillStack.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    func configure(for category: Category, preselected: [String] = []) {
        self.category     = category
        self.selectedTags = Set(preselected)
        rebuild()
    }

    private func rebuild() {
        pillStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let frequent = TagLibrary.frequent(for: category)
        let presets  = (TagLibrary.presets[category] ?? []).filter { !frequent.contains($0) }
        (frequent + presets).forEach { addPill($0) }
    }

    private func addPill(_ tag: String) {
        var config = UIButton.Configuration.plain()
        config.title = tag
        config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer {
            var a = $0; a.font = Theme.Font.title(13); return a   // 볼드
        }
        let b = UIButton(configuration: config)
        b.layer.cornerRadius = 17   // 높이 34의 절반 → 완전한 알약
        b.layer.cornerCurve  = .continuous
        // 각 칩은 자기 콘텐츠 크기 유지 (다른 칩 길이에 끌려가 늘어나지 않게)
        b.setContentHuggingPriority(.required, for: .horizontal)
        b.setContentCompressionResistancePriority(.required, for: .horizontal)
        b.heightAnchor.constraint(equalToConstant: 34).isActive = true
        b.addAction(UIAction { [weak self] _ in self?.toggle(tag, button: b) }, for: .touchUpInside)
        style(b, selected: selectedTags.contains(tag))
        pillStack.addArrangedSubview(b)
    }

    private func toggle(_ tag: String, button: UIButton) {
        Haptic.selection()
        if selectedTags.contains(tag) { selectedTags.remove(tag) } else { selectedTags.insert(tag) }
        style(button, selected: selectedTags.contains(tag))
        onChanged?(Array(selectedTags))
    }

    private func style(_ b: UIButton, selected: Bool) {
        // 선택: 카테고리색 풀필 / 비선택: 회색 필 (테두리 없음)
        b.backgroundColor = selected ? category.color : Theme.Color.groupedBG
        b.configuration?.baseForegroundColor = selected ? .white : Theme.Color.subText
        b.layer.borderWidth = 0
    }
}
