// ViewControllers/AddViewController.swift
import UIKit

final class AddViewController: UIViewController {

    var onSaved: (() -> Void)?
    private var editingExpense: Expense?
    private var isSaving = false
    private var selectedCategory: Category = .food
    private var chips: [CategoryChip] = []
    private var selectedTags: [String] = []
    private var isFixed: Bool = false
    /// 카테고리별 태그·고정여부 임시 캐시 — 칩 전환 시 입력 유지
    private var tagCache: [Category: (tags: [String], isFixed: Bool)] = [:]
    private let tagPicker = TagPickerView()
    /// 고정지출 토글 (옵션 카드에 배치) — 태그 뷰에서 분리
    private let fixedSwitch: UISwitch = {
        let sw = UISwitch()
        sw.onTintColor = Theme.Color.point
        sw.translatesAutoresizingMaskIntoConstraints = false
        return sw
    }()
    
    // MARK: UI
    /// 금액 입력 블록 (₩라벨 + 키패드 + 퀵버튼) — 고정지출 등록 화면과 공유
    private let amountInput = AmountInputView()

    private let memoField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "메모 (선택)"
        tf.font = Theme.Font.body(15)
        tf.borderStyle = .none
        tf.returnKeyType = .done
        tf.translatesAutoresizingMaskIntoConstraints = false
        return tf
    }()
    private var selectedDate = Date()
    /// 날짜 행에 표시되는 "2026. 6. 13. ›" 버튼 (탭 → 날짜 시트)
    private lazy var dateButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.baseForegroundColor = Theme.Color.mainText
        config.image = UIImage(systemName: "chevron.right",
                               withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold))
        config.imagePlacement = .trailing
        config.imagePadding = 6
        config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 4)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer {
            var a = $0; a.font = Theme.Font.body(15); return a
        }
        let b = UIButton(configuration: config)
        b.tintColor = Theme.Color.tertiaryText
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    private lazy var saveButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("저장하기", for: .normal)
        b.titleLabel?.font = Theme.Font.title(17)
        b.setTitleColor(.white, for: .normal)
        b.backgroundColor = Theme.Color.point
        b.layer.cornerRadius = 14
        b.layer.cornerCurve = .continuous
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()
    /// 키보드·저장 버튼에 폼이 가려지지 않도록 전체를 스크롤 가능하게 감싼다
    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.keyboardDismissMode = .interactive
        sv.showsVerticalScrollIndicator = false
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    // MARK: Init
    init(editing expense: Expense?) {
        self.editingExpense = expense
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.Color.background
        title = editingExpense == nil ? "지출 등록" : "지출 수정"
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close, target: self, action: #selector(close))

        buildLayout()
        tagPicker.configure(for: selectedCategory)
        tagPicker.onChanged = { [weak self] tags, _ in
            guard let self else { return }
            self.selectedTags = tags
            self.tagCache[self.selectedCategory] = (tags, self.isFixed)   // 캐시 동기화
        }
        amountInput.onChanged = { [weak self] amount in
            // 버튼은 항상 누를 수 있게 두고, 빈 금액이면 alpha로만 비활성 느낌
            self?.saveButton.alpha = amount > 0 ? 1 : 0.45
        }
        memoField.delegate = self

        // 빈 곳 탭 → 키패드 내리기 (금액 라벨·컨트롤 위 탭은 제외)
        let tapToDismiss = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapToDismiss.cancelsTouchesInView = false
        tapToDismiss.delegate = self
        view.addGestureRecognizer(tapToDismiss)

        if let e = editingExpense { prefill(e) } else { amountInput.setAmount(0) }   // 초기 상태 동기화
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if editingExpense == nil { amountInput.focus() } // 입력 즉시 키패드
    }

    // MARK: Layout
    private func buildLayout() {
        // 카테고리 타일 4개
        let chipRow = UIStackView()
        chipRow.axis = .horizontal
        chipRow.distribution = .fillEqually
        chipRow.spacing = Theme.Space.sm
        chipRow.translatesAutoresizingMaskIntoConstraints = false
        for cat in Category.allCases {
            let chip = CategoryChip(category: cat)
            chip.isSelected = (cat == selectedCategory)
            chip.addTarget(self, action: #selector(chipTapped(_:)), for: .touchUpInside)
            chips.append(chip)
            chipRow.addArrangedSubview(chip)
        }

        // 1) 금액 히어로 — 카드 없이 회색 배경에 직접 (목업 A안)
        amountInput.caption = "얼마를 쓰셨나요?"

        // 2) 카테고리 카드
        let catCard = card()
        let catStack = UIStackView(arrangedSubviews: [makeFieldLabel("카테고리"), chipRow])
        catStack.axis = .vertical; catStack.spacing = Theme.Space.sm
        embed(catStack, in: catCard)

        // 3) 태그 카드 (고정지출 토글은 옵션 카드로 분리하므로 여기선 숨김)
        tagPicker.setFixedToggleHidden(true)
        let tagCard = card()
        let tagStack = UIStackView(arrangedSubviews: [makeFieldLabel("태그"), tagPicker])
        tagStack.axis = .vertical; tagStack.spacing = Theme.Space.sm
        embed(tagStack, in: tagCard)

        // 4) 옵션 카드 — 날짜 / 메모 / 고정지출 (행 형태)
        let optionCard = card()
        fixedSwitch.addTarget(self, action: #selector(fixedSwitchChanged), for: .valueChanged)
        dateButton.addTarget(self, action: #selector(dateTapped), for: .touchUpInside)
        dateButton.addTarget(self, action: #selector(dateButtonDown), for: [.touchDown, .touchDragEnter])
        dateButton.addTarget(self, action: #selector(dateButtonUp), for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])
        updateDateButton()
        let dateRow = optionRow("날짜", dateButton)
        memoField.textAlignment = .right
        let memoRow = optionRow("메모", memoField)
        let fixedRow = optionRow("고정지출", fixedSwitch)
        let optStack = UIStackView(arrangedSubviews: [dateRow, hairline(), memoRow, hairline(), fixedRow])
        optStack.axis = .vertical; optStack.spacing = Theme.Space.md
        embed(optStack, in: optionCard)

        let stack = UIStackView(arrangedSubviews: [amountInput, catCard, tagCard, optionCard])
        stack.axis = .vertical
        stack.spacing = Theme.Space.md
        stack.setCustomSpacing(Theme.Space.xl, after: amountInput)   // 히어로 아래 넉넉히
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: Theme.Space.xl, left: 0, bottom: 0, right: 0)

        view.addSubview(scrollView)
        scrollView.addSubview(stack)
        view.addSubview(saveButton)
        saveButton.addTarget(self, action: #selector(save), for: .touchUpInside)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: saveButton.topAnchor, constant: -Theme.Space.sm),

            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: Theme.Space.md),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: Theme.Space.lg),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -Theme.Space.lg),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -Theme.Space.md),
            stack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -2 * Theme.Space.lg),

            saveButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Theme.Space.lg),
            saveButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Theme.Space.lg),
            saveButton.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor, constant: -Theme.Space.md),
            saveButton.heightAnchor.constraint(equalToConstant: 54),
        ])
    }

    // MARK: Builders
    /// 흰 카드 생성
    private func card(padding: UIEdgeInsets = UIEdgeInsets(top: Theme.Space.lg, left: Theme.Space.lg,
                                                           bottom: Theme.Space.lg, right: Theme.Space.lg)) -> UIView {
        let v = UIView()
        v.backgroundColor = Theme.Color.card
        v.layer.cornerRadius = Theme.Radius.lg
        v.layer.cornerCurve = .continuous
        v.translatesAutoresizingMaskIntoConstraints = false
        Theme.applyCardShadow(to: v.layer, opacity: 0.05, radius: 16, y: 4)
        v.layoutMargins = padding
        return v
    }
    /// 카드 안에 콘텐츠를 layoutMargins 기준으로 채운다
    private func embed(_ content: UIView, in card: UIView) {
        content.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(content)
        let m = card.layoutMarginsGuide
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: m.topAnchor),
            content.leadingAnchor.constraint(equalTo: m.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: m.trailingAnchor),
            content.bottomAnchor.constraint(equalTo: m.bottomAnchor),
        ])
    }
    /// 좌측 라벨 + 우측 값 형태의 옵션 행
    private func optionRow(_ title: String, _ control: UIView) -> UIView {
        let label = UILabel()
        label.text = title
        label.font = Theme.Font.title(15)   // 볼드
        label.textColor = Theme.Color.mainText
        label.translatesAutoresizingMaskIntoConstraints = false
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        control.translatesAutoresizingMaskIntoConstraints = false
        control.setContentHuggingPriority(.required, for: .horizontal)
        // 라벨과 컨트롤 사이 신축 스페이서 → 컨트롤이 항상 우측 끝
        let spacer = UIView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let row = UIStackView(arrangedSubviews: [label, spacer, control])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = Theme.Space.md
        return row
    }
    private func hairline() -> UIView {
        let v = UIView()
        v.backgroundColor = Theme.Color.hairline
        v.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return v
    }

    // MARK: Builders
    private func makeFieldLabel(_ t: String) -> UILabel {
        let l = UILabel(); l.text = t
        l.font = Theme.Font.title(15); l.textColor = Theme.Color.mainText   // 볼드
        return l
    }
    // MARK: Logic
    private func prefill(_ e: Expense) {
        selectedCategory = e.category
        amountInput.setAmount(e.amount)
        memoField.text = e.memo
        selectedDate = e.date
        updateDateButton()
        chips.forEach { $0.isSelected = ($0.category == e.category) }
        selectedTags = e.tags
        isFixed = e.isFixed
        fixedSwitch.isOn = e.isFixed
        tagPicker.configure(for: e.category, preselected: e.tags, isFixed: e.isFixed)
        
        tagCache[e.category] = (e.tags, e.isFixed)
    }

    @objc private func chipTapped(_ chip: CategoryChip) {
        Haptic.selection()
        selectedCategory = chip.category
        // 캐시에 저장된 태그가 있으면 복원, 없으면 빈 상태
        let cached = tagCache[selectedCategory]
        selectedTags = cached?.tags ?? []
        isFixed = cached?.isFixed ?? false
        fixedSwitch.isOn = isFixed
        tagPicker.configure(for: selectedCategory, preselected: selectedTags, isFixed: isFixed)
        UIView.animate(withDuration: 0.2) {
            self.chips.forEach { $0.isSelected = ($0 === chip) }
        }
    }

    @objc private func save() {
        guard !isSaving else { return }
        // 빈 금액 — 저장 막고 흔들림 + 안내
        guard amountInput.amount > 0 else {
            Haptic.warning()
            amountInput.shake()
            Toast.show("금액을 입력해주세요", style: Toast.Style.info, in: view, duration: 1.4)   // in: view → keyboardLayoutGuide로 키패드 위에 표시
            amountInput.focus()
            return
        }
        isSaving = true
        saveButton.isEnabled = false

        Haptic.success()
        let memo = memoField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        TagLibrary.record(selectedTags, for: selectedCategory)

        if let target = editingExpense {
            // 편집 도중 다른 경로로 삭제된 객체면 조용히 부활시키지 않는다
            // (modelContext nil 체크는 iOS 17에서 정상 객체에도 nil을 반환할 수 있어 스토어 캐시로 판별)
            guard ExpenseStore.shared.contains(id: target.id) else {
                ExpenseStore.shared.reloadFromDisk()
                dismiss(animated: true) { Toast.show("이미 삭제된 항목이에요", style: .info) }
                return
            }
            // live @Model 직접 수정 — recurringID는 건드리지 않으므로 고정지출 링크가 보존된다
            target.category = selectedCategory
            target.amount   = amountInput.amount
            target.memo     = memo
            target.date     = selectedDate
            target.tags     = selectedTags
            target.isFixed  = isFixed
            ExpenseStore.shared.saveChanges()
        } else {
            ExpenseStore.shared.add(Expense(
                category: selectedCategory,
                amount: amountInput.amount,
                memo: memo,
                date: selectedDate,
                tags: selectedTags,
                isFixed: isFixed))
        }
        dismiss(animated: true) { [weak self] in self?.onSaved?() }
    }

    @objc private func fixedSwitchChanged() {
        isFixed = fixedSwitch.isOn
        tagCache[selectedCategory] = (selectedTags, isFixed)
    }

    /// 날짜 행 탭 → 휠 데이트피커 시트
    @objc private func dateButtonDown() {
        UIView.animate(withDuration: 0.1) { self.dateButton.alpha = 0.4 }
    }
    @objc private func dateButtonUp() {
        UIView.animate(withDuration: 0.1) { self.dateButton.alpha = 1 }
    }

    @objc private func dateTapped() {
        Haptic.selection()
        view.endEditing(true)
        let sheet = DatePickerSheet(date: selectedDate)
        sheet.onPick = { [weak self] picked in
            self?.selectedDate = picked
            self?.updateDateButton()
        }
        if let s = sheet.sheetPresentationController {
            s.detents = [.medium()]
            s.prefersGrabberVisible = true
        }
        present(sheet, animated: true)
    }

    private func updateDateButton() {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "yyyy. M. d."
        dateButton.configuration?.title = f.string(from: selectedDate)
    }

    @objc private func close() { dismiss(animated: true) }

    @objc private func dismissKeyboard() { view.endEditing(true) }
}

extension AddViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ tf: UITextField) -> Bool { tf.resignFirstResponder(); return true }
    /// 키보드가 올라온 뒤 포커스 필드를 스크롤로 끌어올린다 (저장 버튼에 가려짐 방지)
    func textFieldDidBeginEditing(_ tf: UITextField) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.view.layoutIfNeeded()
            let rect = tf.convert(tf.bounds, to: self.scrollView).insetBy(dx: 0, dy: -Theme.Space.lg)
            self.scrollView.scrollRectToVisible(rect, animated: true)
        }
    }
}

extension AddViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ g: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard let v = touch.view else { return true }
        if v.isDescendant(of: amountInput) || v is UIControl || v is UITextField { return false }
        return true
    }
}
