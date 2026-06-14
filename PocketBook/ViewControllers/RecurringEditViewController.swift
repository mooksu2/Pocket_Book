import UIKit

/// 고정지출 등록·수정 폼. 메모 / 금액 / 카테고리 / 매월 며칠.
final class RecurringEditViewController: CardFormViewController {

    var onSaved: (() -> Void)?

    private let editingItem: RecurringExpense?
    private var selectedCategory: Category = .food
    private var chips: [CategoryChip] = []
    private var dayOfMonth = 1
    private var isSaving = false
    private let tagPicker = TagPickerView()
    /// 카테고리 전환 시 태그 선택을 보관했다가 돌아오면 복원
    private var tagCache: [Category: [String]] = [:]

    // MARK: UI
    private let nameField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "메모 (예: 월세, 넷플릭스)"
        tf.font = Theme.Font.body(15)
        tf.borderStyle = .none
        tf.returnKeyType = .done
        tf.clearButtonMode = .whileEditing
        tf.translatesAutoresizingMaskIntoConstraints = false
        return tf
    }()
    /// 금액 입력 블록 (₩라벨 + 키패드 + 퀵버튼) — 지출 입력 화면과 공유
    private let amountInput = AmountInputView()
    /// 결제일 선택 버튼 (탭하면 휠 피커 시트) — "매월 N일 ›"
    private lazy var dayButton: UIButton = {
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
    /// 수정 시 안내 힌트
    private let editHintLabel: UILabel = {
        let l = UILabel()
        l.font = Theme.Font.caption(12)
        l.textColor = Theme.Color.subText
        l.numberOfLines = 0
        l.text = "ℹ️ 변경 내용은 아직 기록되지 않은 결제부터 적용돼요. 이미 기록된 지출은 그대로 유지됩니다."
        l.isHidden = true
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // MARK: Init
    init(editing item: RecurringExpense?) {
        self.editingItem = item
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()   // 스캐폴드 구성
        title = editingItem == nil ? "고정지출 등록" : "고정지출 수정"
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close, target: self, action: #selector(close))

        protectedTapView = amountInput

        amountInput.onChanged = { [weak self] amount in
            self?.saveButton.alpha = amount > 0 ? 1 : 0.45
        }
        nameField.delegate = self

        editHintLabel.isHidden = (editingItem == nil)

        if let it = editingItem { prefill(it) } else {
            tagPicker.configure(for: selectedCategory)
            amountInput.setAmount(0)   // 초기 상태 동기화
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if editingItem == nil { amountInput.focus() }   // 신규 등록 즉시 키패드
    }

    // MARK: Form body
    override func makeFormStack() -> UIStackView {
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

        amountInput.caption = "매달 얼마가 나가나요?"

        let catCard = card()
        let catStack = UIStackView(arrangedSubviews: [makeFieldLabel("카테고리"), chipRow])
        catStack.axis = .vertical; catStack.spacing = Theme.Space.sm
        embed(catStack, in: catCard)

        let tagCard = card()
        let tagStack = UIStackView(arrangedSubviews: [makeFieldLabel("태그"), tagPicker])
        tagStack.axis = .vertical; tagStack.spacing = Theme.Space.sm
        embed(tagStack, in: tagCard)

        // 옵션 카드 — 메모 / 결제일
        nameField.textAlignment = .right
        let memoRow = optionRow("메모", nameField)
        dayButton.addTarget(self, action: #selector(openDayPicker), for: .touchUpInside)
        dayButton.addTarget(self, action: #selector(dayButtonDown), for: [.touchDown, .touchDragEnter])
        dayButton.addTarget(self, action: #selector(dayButtonUp), for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])
        updateDayButton()
        let dayRow = optionRow("결제일", dayButton)
        let optionCard = card()
        let optStack = UIStackView(arrangedSubviews: [memoRow, hairline(), dayRow])
        optStack.axis = .vertical; optStack.spacing = Theme.Space.md
        embed(optStack, in: optionCard)

        let stack = UIStackView(arrangedSubviews: [amountInput, catCard, tagCard, optionCard, editHintLabel])
        stack.axis = .vertical
        stack.spacing = Theme.Space.md
        stack.setCustomSpacing(Theme.Space.xl, after: amountInput)
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: Theme.Space.xl, left: 0, bottom: 0, right: 0)
        return stack
    }

    private func updateDayButton() {
        dayButton.configuration?.title = "매월 \(dayOfMonth)일"
    }
    @objc private func dayButtonDown() {
        UIView.animate(withDuration: 0.1) { self.dayButton.alpha = 0.4 }
    }
    @objc private func dayButtonUp() {
        UIView.animate(withDuration: 0.1) { self.dayButton.alpha = 1 }
    }

    // MARK: Logic
    private func prefill(_ it: RecurringExpense) {
        selectedCategory = it.category
        amountInput.setAmount(it.amount)
        nameField.text = it.name
        dayOfMonth = it.dayOfMonth
        updateDayButton()
        chips.forEach { $0.isSelected = ($0.category == it.category) }
        tagPicker.configure(for: it.category, preselected: it.tags)
    }

    @objc private func chipTapped(_ chip: CategoryChip) {
        Haptic.selection()
        tagCache[selectedCategory] = Array(tagPicker.selectedTags)   // 떠나는 카테고리의 선택 보관
        selectedCategory = chip.category
        tagPicker.configure(for: selectedCategory,
                            preselected: tagCache[selectedCategory] ?? [])
        UIView.animate(withDuration: 0.2) {
            self.chips.forEach { $0.isSelected = ($0 === chip) }
        }
    }

    /// 결제일 휠 피커 시트 — 1~31일을 한 번에 스크롤 선택
    @objc private func openDayPicker() {
        Haptic.selection()
        view.endEditing(true)
        let picker = DayPickerSheet(selected: dayOfMonth) { [weak self] day in
            guard let self else { return }
            self.dayOfMonth = day
            self.updateDayButton()
            Haptic.selection()
        }
        picker.modalPresentationStyle = .pageSheet
        if let sheet = picker.sheetPresentationController {
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = true
        }
        presentOnce(picker)
    }

    override func didTapSave() {
        guard !isSaving else { return }
        guard amountInput.amount > 0 else {
            Haptic.warning()
            amountInput.shake()
            Toast.show("금액을 입력해주세요", style: Toast.Style.info, in: view, duration: 1.4)
            amountInput.focus()
            return
        }
        isSaving = true
        saveButton.isEnabled = false

        let name = nameField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        Haptic.success()

        if let target = editingItem {
            // 편집 도중 다른 경로로 삭제된 규칙이면 조용히 부활시키지 않는다
            guard RecurringStore.shared.item(id: target.id) != nil else {
                RecurringStore.shared.load()
                dismiss(animated: true) { Toast.show("이미 삭제된 고정지출이에요", style: .info) }
                return
            }
            // live @Model 직접 수정 — 새 인스턴스를 만들어 던지면 context에 반영되지 않는다
            target.name       = name
            target.amount     = amountInput.amount
            target.category   = selectedCategory
            target.dayOfMonth = max(1, min(31, dayOfMonth))
            target.tags       = Array(tagPicker.selectedTags)
            RecurringStore.shared.saveChanges()   // 저장 + 이번 달 미생성분 즉시 반영 + 통지
        } else {
            RecurringStore.shared.add(RecurringExpense(
                name: name,
                amount: amountInput.amount,
                category: selectedCategory,
                dayOfMonth: dayOfMonth,
                tags: Array(tagPicker.selectedTags)))
        }
        dismiss(animated: true) { [weak self] in self?.onSaved?() }
    }

    @objc private func close() { dismiss(animated: true) }
}

// MARK: - DayPickerSheet (1~31일 휠 선택 시트)
final class DayPickerSheet: UIViewController {

    private let initialDay: Int
    private let onPick: (Int) -> Void
    private let picker = UIPickerView()

    init(selected day: Int, onPick: @escaping (Int) -> Void) {
        self.initialDay = min(max(day, 1), 31)
        self.onPick = onPick
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.Color.background

        let titleLabel = UILabel()
        titleLabel.text = "결제일 선택"
        titleLabel.font = Theme.Font.title(17)
        titleLabel.textColor = Theme.Color.mainText
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let doneButton = UIButton(type: .system)
        doneButton.setTitle("완료", for: .normal)
        doneButton.titleLabel?.font = Theme.Font.title(16)
        doneButton.setTitleColor(Theme.Color.point, for: .normal)
        doneButton.translatesAutoresizingMaskIntoConstraints = false
        doneButton.addTarget(self, action: #selector(done), for: .touchUpInside)

        picker.dataSource = self
        picker.delegate = self
        picker.translatesAutoresizingMaskIntoConstraints = false
        picker.selectRow(initialDay - 1, inComponent: 0, animated: false)

        view.addSubview(titleLabel)
        view.addSubview(doneButton)
        view.addSubview(picker)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Theme.Space.lg),

            doneButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            doneButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Theme.Space.lg),

            picker.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            picker.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            picker.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            picker.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
        ])
    }

    @objc private func done() {
        let day = picker.selectedRow(inComponent: 0) + 1
        onPick(day)
        dismiss(animated: true)
    }
}

extension DayPickerSheet: UIPickerViewDataSource, UIPickerViewDelegate {
    func numberOfComponents(in pickerView: UIPickerView) -> Int { 1 }
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int { 31 }
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        "\(row + 1)일"
    }
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        Haptic.selection()
    }
}
