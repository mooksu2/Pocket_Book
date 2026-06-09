import UIKit

/// 고정지출 등록·수정 폼. 메모 / 금액 / 카테고리 / 매월 며칠.
final class RecurringEditViewController: UIViewController {

    var onSaved: (() -> Void)?

    private let editingItem: RecurringExpense?
    private var selectedCategory: Category = .food
    private var chips: [CategoryChip] = []
    private var amountValue = 0
    private var dayOfMonth = 1
    private let tagPicker = TagPickerView()

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
    private let amountLabel: UILabel = {
        let l = UILabel()
        l.text = "₩0"
        l.font = Theme.Font.money(48, .heavy)
        l.textColor = Theme.Color.tertiaryText
        l.textAlignment = .center
        l.adjustsFontSizeToFitWidth = true
        l.minimumScaleFactor = 0.5
        l.isUserInteractionEnabled = true
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    /// 숫자 키패드용 숨은 필드
    private let hiddenField: UITextField = {
        let tf = UITextField()
        tf.keyboardType = .numberPad
        tf.isHidden = true
        return tf
    }()
    private let dayValueLabel: UILabel = {
        let l = UILabel()
        l.text = "매월 1일"
        l.font = Theme.Font.title(16)
        l.textColor = Theme.Color.mainText
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    private let dayStepper: UIStepper = {
        let s = UIStepper()
        s.minimumValue = 1
        s.maximumValue = 31
        s.value = 1
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
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
    private var saveButtonBottom: NSLayoutConstraint!

    // MARK: Init
    init(editing item: RecurringExpense?) {
        self.editingItem = item
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.Color.background
        title = editingItem == nil ? "고정지출 등록" : "고정지출 수정"
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close, target: self, action: #selector(close))

        buildLayout()
        view.addSubview(hiddenField)
        hiddenField.addTarget(self, action: #selector(amountTyping), for: .editingChanged)
        nameField.delegate = self
        dayStepper.addTarget(self, action: #selector(dayChanged), for: .valueChanged)

        tagPicker.setFixedToggleHidden(true)   // 고정지출 화면이라 토글 불필요, 태그만 사용

        // 빈 곳 탭 → 키패드 내리기 (금액 라벨·컨트롤 위 탭은 제외)
        let tapToDismiss = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapToDismiss.cancelsTouchesInView = false
        tapToDismiss.delegate = self
        view.addGestureRecognizer(tapToDismiss)

        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChange(_:)),
                                               name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)),
                                               name: UIResponder.keyboardWillHideNotification, object: nil)

        if let it = editingItem { prefill(it) } else { tagPicker.configure(for: selectedCategory) }
        refresh()
    }

    // MARK: Layout
    private func buildLayout() {
        // 카테고리 칩 4개
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

        // 금액 (탭 → 키패드)
        let amountTap = UITapGestureRecognizer(target: self, action: #selector(focusAmount))
        amountLabel.addGestureRecognizer(amountTap)

        // 결제일 행: 좌측 라벨 + 우측 스테퍼
        let dayRow = UIStackView(arrangedSubviews: [dayValueLabel, dayStepper])
        dayRow.axis = .horizontal
        dayRow.alignment = .center
        dayRow.distribution = .equalSpacing

        let nameSection = labeledCard("메모", nameField)
        let daySection  = labeledCard("결제일 (매월)", dayRow)

        let amountSeparator = UIView()
        amountSeparator.backgroundColor = Theme.Color.hairline
        amountSeparator.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView(arrangedSubviews: [
            makeFieldLabel("카테고리"), chipRow,
            amountSeparator, amountLabel,
            makeFieldLabel("태그"), tagPicker,
            nameSection, daySection,
        ])
        stack.axis = .vertical
        stack.spacing = Theme.Space.sm
        stack.setCustomSpacing(Theme.Space.lg, after: chipRow)
        stack.setCustomSpacing(Theme.Space.lg, after: amountLabel)
        stack.setCustomSpacing(Theme.Space.lg, after: tagPicker)
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)
        view.addSubview(saveButton)
        saveButton.addTarget(self, action: #selector(save), for: .touchUpInside)

        saveButtonBottom = saveButton.bottomAnchor.constraint(
            equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -Theme.Space.md)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: Theme.Space.xl),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Theme.Space.lg),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Theme.Space.lg),
            chipRow.heightAnchor.constraint(equalToConstant: 64),
            amountSeparator.heightAnchor.constraint(equalToConstant: 1),

            saveButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Theme.Space.lg),
            saveButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Theme.Space.lg),
            saveButtonBottom,
            saveButton.heightAnchor.constraint(equalToConstant: 54),
        ])
    }

    // MARK: Builders
    private func makeFieldLabel(_ t: String) -> UILabel {
        let l = UILabel(); l.text = t
        l.font = Theme.Font.caption(13); l.textColor = Theme.Color.subText
        return l
    }
    private func spacer(_ h: CGFloat) -> UIView {
        let v = UIView(); v.heightAnchor.constraint(equalToConstant: h).isActive = true; return v
    }
    private func labeledCard(_ title: String, _ content: UIView) -> UIView {
        let label = makeFieldLabel(title)
        let bg = UIView()
        bg.backgroundColor = Theme.Color.groupedBG
        bg.roundCorners(Theme.Radius.sm)
        bg.translatesAutoresizingMaskIntoConstraints = false
        content.translatesAutoresizingMaskIntoConstraints = false
        bg.addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: bg.leadingAnchor, constant: Theme.Space.md),
            content.trailingAnchor.constraint(equalTo: bg.trailingAnchor, constant: -Theme.Space.md),
            content.topAnchor.constraint(equalTo: bg.topAnchor, constant: 12),
            content.bottomAnchor.constraint(equalTo: bg.bottomAnchor, constant: -12),
        ])
        let stack = UIStackView(arrangedSubviews: [label, bg])
        stack.axis = .vertical
        stack.spacing = 4
        return stack
    }

    // MARK: Keyboard (저장 버튼을 키보드 위로 — iOS 14 호환)
    @objc private func keyboardWillChange(_ note: Notification) {
        guard let value = (note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue else { return }
        let kb = view.convert(value, from: nil)
        let overlap = max(view.bounds.maxY - kb.minY - view.safeAreaInsets.bottom, 0)
        saveButtonBottom.constant = -(overlap + Theme.Space.md)
        UIView.animate(withDuration: 0.25) { self.view.layoutIfNeeded() }
    }
    @objc private func keyboardWillHide(_ note: Notification) {
        saveButtonBottom.constant = -Theme.Space.md
        UIView.animate(withDuration: 0.25) { self.view.layoutIfNeeded() }
    }

    // MARK: Logic
    private func prefill(_ it: RecurringExpense) {
        selectedCategory = it.category
        amountValue = it.amount
        nameField.text = it.name
        dayOfMonth = it.dayOfMonth
        hiddenField.text = "\(it.amount)"
        dayStepper.value = Double(it.dayOfMonth)
        dayValueLabel.text = "매월 \(it.dayOfMonth)일"
        chips.forEach { $0.isSelected = ($0.category == it.category) }
        tagPicker.configure(for: it.category, preselected: it.tags)
    }

    @objc private func chipTapped(_ chip: CategoryChip) {
        Haptic.selection()
        selectedCategory = chip.category
        tagPicker.configure(for: selectedCategory)   // 카테고리별 태그 갱신
        UIView.animate(withDuration: 0.2) {
            self.chips.forEach { $0.isSelected = ($0 === chip) }
        }
    }

    @objc private func focusAmount() { hiddenField.becomeFirstResponder() }

    @objc private func amountTyping() {
        let digits = (hiddenField.text ?? "").filter(\.isNumber)
        let trimmed = String(digits.prefix(9))
        hiddenField.text = trimmed
        amountValue = Int(trimmed) ?? 0
        refresh()
    }

    @objc private func dayChanged() {
        dayOfMonth = Int(dayStepper.value)
        dayValueLabel.text = "매월 \(dayOfMonth)일"
        Haptic.selection()
    }

    private func refresh() {
        amountLabel.text = amountValue.won
        amountLabel.textColor = amountValue > 0 ? Theme.Color.mainText : Theme.Color.tertiaryText
        let valid = amountValue > 0
        saveButton.isEnabled = valid
        saveButton.alpha = valid ? 1 : 0.45
    }

    @objc private func save() {
        let name = nameField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        guard amountValue > 0 else { return }
        Haptic.success()
        let item = RecurringExpense(
            id: editingItem?.id ?? UUID(),
            name: name,
            amount: amountValue,
            category: selectedCategory,
            dayOfMonth: dayOfMonth,
            isActive: editingItem?.isActive ?? true,
            tags: Array(tagPicker.selectedTags))
        if editingItem == nil { RecurringStore.shared.add(item) }
        else { RecurringStore.shared.update(item) }
        dismiss(animated: true) { [weak self] in self?.onSaved?() }
    }

    @objc private func close() { dismiss(animated: true) }

    @objc private func dismissKeyboard() { view.endEditing(true) }
}

extension RecurringEditViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ g: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard let v = touch.view else { return true }
        // 금액 라벨·버튼·스위치·텍스트필드 위 탭은 무시 (키패드 토글 충돌 방지)
        if v.isDescendant(of: amountLabel) || v is UIControl || v is UITextField { return false }
        return true
    }
}

extension RecurringEditViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ tf: UITextField) -> Bool { tf.resignFirstResponder(); return true }
    func textField(_ tf: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        DispatchQueue.main.async { [weak self] in self?.refresh() }
        return true
    }
}
