// Views/CategoryFilterBar.swift
import UIKit

/// 카테고리 필터 + 우측 끝 검색 버튼.
/// 검색 버튼 탭 → 같은 공간에서 텍스트 필드로 전환, 취소 시 원복.
final class CategoryFilterBar: UIView {

    var onSelect: ((Category?) -> Void)?
    var onSearchChanged: ((String) -> Void)?

    private var selected: Category?
    private var pills: [(cat: Category?, button: UIButton)] = []

    // MARK: 기본 상태 (카테고리 필터)
    private let scroll: UIScrollView = {
        let s = UIScrollView()
        s.showsHorizontalScrollIndicator = false
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()
    private let stack: UIStackView = {
        let s = UIStackView()
        s.axis = .horizontal
        s.spacing = 8
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()
    private let searchButton: UIButton = {
        let b = UIButton(type: .system)
        b.setImage(UIImage(systemName: "magnifyingglass",
                           withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)), for: .normal)
        b.tintColor = Theme.Color.point
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    // MARK: 검색 상태
    private let searchContainer: UIView = {
        let v = UIView()
        v.backgroundColor = Theme.Color.background   // 뒤 필터칩 가림
        v.isHidden = true
        v.alpha = 0
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()
    private let fieldBg: UIView = {
        let v = UIView()
        v.backgroundColor = Theme.Color.card   // 흰색 — 회색 배경에서 떠 보이게
        v.layer.cornerRadius = 16
        v.layer.cornerCurve = .continuous
        Theme.applyCardShadow(to: v.layer, opacity: 0.06, radius: 6, y: 2)
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()
    private let searchField: UITextField = {
        let f = UITextField()
        f.placeholder = "메모·카테고리 검색"
        f.font = Theme.Font.body(14)
        f.returnKeyType = .search
        f.clearButtonMode = .whileEditing
        f.translatesAutoresizingMaskIntoConstraints = false
        return f
    }()
    private let cancelButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("취소", for: .normal)
        b.titleLabel?.font = Theme.Font.body(14)
        b.setTitleColor(Theme.Color.point, for: .normal)
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Theme.Color.background   // 위로 스크롤되는 카드를 가린다
        scroll.addSubview(stack)

        // 🔍 아이콘 (필드 내부 왼쪽)
        let icon = UIImageView(image: UIImage(systemName: "magnifyingglass",
                                              withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .medium)))
        icon.tintColor = Theme.Color.tertiaryText
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        fieldBg.addSubview(icon)
        fieldBg.addSubview(searchField)
        searchContainer.addSubview(fieldBg)
        searchContainer.addSubview(cancelButton)

        [scroll, searchButton, searchContainer].forEach { addSubview($0) }

        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: topAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: searchButton.leadingAnchor, constant: -6),

            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: Theme.Space.lg),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -Theme.Space.sm),
            stack.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor),

            searchButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Theme.Space.lg),
            searchButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            searchButton.widthAnchor.constraint(equalToConstant: 30),
            searchButton.heightAnchor.constraint(equalToConstant: 30),

            searchContainer.topAnchor.constraint(equalTo: topAnchor),
            searchContainer.bottomAnchor.constraint(equalTo: bottomAnchor),
            searchContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Theme.Space.lg),
            searchContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Theme.Space.lg),

            cancelButton.trailingAnchor.constraint(equalTo: searchContainer.trailingAnchor),
            cancelButton.centerYAnchor.constraint(equalTo: searchContainer.centerYAnchor),

            fieldBg.leadingAnchor.constraint(equalTo: searchContainer.leadingAnchor),
            fieldBg.trailingAnchor.constraint(equalTo: cancelButton.leadingAnchor, constant: -8),
            fieldBg.topAnchor.constraint(equalTo: searchContainer.topAnchor, constant: 2),
            fieldBg.bottomAnchor.constraint(equalTo: searchContainer.bottomAnchor, constant: -2),

            icon.leadingAnchor.constraint(equalTo: fieldBg.leadingAnchor, constant: 10),
            icon.centerYAnchor.constraint(equalTo: fieldBg.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 14),
            icon.heightAnchor.constraint(equalToConstant: 14),

            searchField.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 6),
            searchField.trailingAnchor.constraint(equalTo: fieldBg.trailingAnchor, constant: -8),
            searchField.topAnchor.constraint(equalTo: fieldBg.topAnchor),
            searchField.bottomAnchor.constraint(equalTo: fieldBg.bottomAnchor),
        ])

        searchButton.addTarget(self, action: #selector(openSearch), for: .touchUpInside)
        cancelButton.addTarget(self, action: #selector(closeSearch), for: .touchUpInside)
        searchField.addTarget(self, action: #selector(textChanged), for: .editingChanged)
        searchField.delegate = self

        addPill(title: "전체", cat: nil)
        for cat in Category.allCases { addPill(title: cat.rawValue, cat: cat) }
        refresh()
    }
    required init?(coder: NSCoder) { fatalError() }

    @objc private func openSearch() {
        Haptic.selection()
        selected = nil; refresh(); onSelect?(nil)

        searchContainer.isHidden = false
        UIView.animate(withDuration: 0.22, delay: 0, options: .curveEaseOut) {
            self.scroll.alpha = 0
            self.searchButton.alpha = 0
            self.searchContainer.alpha = 1
        } completion: { _ in
            self.scroll.isHidden = true
            self.searchField.becomeFirstResponder()
        }
    }

    @objc private func closeSearch() {
        searchField.resignFirstResponder()
        searchField.text = nil
        onSearchChanged?("")

        scroll.isHidden = false
        UIView.animate(withDuration: 0.22, delay: 0, options: .curveEaseIn) {
            self.scroll.alpha = 1
            self.searchButton.alpha = 1
            self.searchContainer.alpha = 0
        } completion: { _ in
            self.searchContainer.isHidden = true
        }
    }

    @objc private func textChanged() {
        onSearchChanged?(searchField.text ?? "")
    }

    private func addPill(title: String, cat: Category?) {
        var config = UIButton.Configuration.plain()
        config.title = title
        config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer {
            var a = $0; a.font = Theme.Font.caption(13); return a
        }
        let b = UIButton(configuration: config)
        b.layer.cornerRadius = 20
        b.layer.cornerCurve = .circular
        b.clipsToBounds = true
        b.heightAnchor.constraint(equalToConstant: 34).isActive = true
        b.addAction(UIAction { [weak self] _ in self?.tap(cat) }, for: .touchUpInside)
        pills.append((cat, b))
        stack.addArrangedSubview(b)
    }

    private func tap(_ cat: Category?) {
        guard selected != cat else { return }
        Haptic.selection()
        selected = cat; refresh(); onSelect?(cat)
    }

    private func refresh() {
        for (cat, b) in pills {
            let isOn = (cat == selected)
            // 선택 시 항상 포인트 블루 채움 (비선택은 회색 필, 테두리 없음)
            // 선택 시 파란 채움, 비선택은 투명 (배경에 녹아드는 텍스트만)
            b.backgroundColor = isOn ? Theme.Color.point : .clear
            b.configuration?.baseForegroundColor = isOn ? .white : Theme.Color.subText
        }
    }
}

extension CategoryFilterBar: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder(); return true
    }
}
