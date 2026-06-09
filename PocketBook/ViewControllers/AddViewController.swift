// ViewControllers/AddViewController.swift
import UIKit

final class AddViewController: UIViewController {

    var onSaved: (() -> Void)?
    private var editingExpanse: Expense?
    private var isSaving = false
    private var selectedCategory: Category = .food
    private var chips: [CategoryChip] = []
    private var amountValue = 0
    private var selectedTags: [String] = []
    private var isFixed: Bool = false
    /// 카테고리별 태그·고정여부 임시 캐시 — 칩 전환 시 입력 유지
    private var tagCache: [Category: (tags: [String], isFixed: Bool)] = [:]
    private let tagPicker = TagPickerView()
    
    // MARK: UI
    private let amountLabel: UILabel = {
        let l = UILabel()
        l.text = "₩0"
        l.font = Theme.Font.money(48, .heavy)
        l.textColor = Theme.Color.tertiaryText
        l.textAlignment = .center
        l.adjustsFontSizeToFitWidth = true
        l.minimumScaleFactor = 0.5
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    /// 숫자 키패드를 띄우기 위한 숨은 필드
    private let hiddenField: UITextField = {
        let tf = UITextField()
        tf.keyboardType = .numberPad
        tf.isHidden = true
        return tf
    }()

    private let memoField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "메모 (선택)"
        tf.font = Theme.Font.body(15)
        tf.borderStyle = .none
        tf.returnKeyType = .done
        tf.translatesAutoresizingMaskIntoConstraints = false
        return tf
    }()
    private let datePicker: UIDatePicker = {
        let dp = UIDatePicker()
        dp.datePickerMode = .date
        dp.preferredDatePickerStyle = .compact
        dp.locale = Locale(identifier: "ko_KR")
        dp.translatesAutoresizingMaskIntoConstraints = false
        return dp
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
    init(editing expense: Expense?) {
        self.editingExpanse = expense
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.Color.background
        title = editingExpanse == nil ? "지출 입력" : "지출 수정"
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close, target: self, action: #selector(close))

        buildLayout()
        tagPicker.configure(for: selectedCategory)
        tagPicker.onChanged = { [weak self] tags, fixed in
            guard let self else { return }
            self.selectedTags = tags
            self.isFixed = fixed
            self.tagCache[self.selectedCategory] = (tags, fixed)   // 캐시 동기화
        }
        view.addSubview(hiddenField)
        hiddenField.addTarget(self, action: #selector(amountTyping), for: .editingChanged)
        memoField.delegate = self

        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChange(_:)),
                                               name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)),
                                               name: UIResponder.keyboardWillHideNotification, object: nil)

        // 빈 곳 탭 → 키패드 내리기 (금액 라벨·컨트롤 위 탭은 제외)
        let tapToDismiss = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapToDismiss.cancelsTouchesInView = false
        tapToDismiss.delegate = self
        view.addGestureRecognizer(tapToDismiss)

        if let e = editingExpanse { prefill(e) }
        refresh()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if editingExpanse == nil { hiddenField.becomeFirstResponder() } // 입력 즉시 키패드
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

        // 금액 (탭하면 키패드)
        let amountTap = UITapGestureRecognizer(target: self, action: #selector(focusAmount))
        amountLabel.isUserInteractionEnabled = true
        amountLabel.addGestureRecognizer(amountTap)

        // 빠른 금액 버튼
        let quickRow = UIStackView()
        quickRow.axis = .horizontal
        quickRow.distribution = .fillEqually
        quickRow.spacing = Theme.Space.sm
        quickRow.translatesAutoresizingMaskIntoConstraints = false
        [1000, 5000, 10000, 50000].forEach { amt in
            quickRow.addArrangedSubview(makeQuickButton(amt))
        }

        let memoSection = labeledCard("메모", memoField)
        let dateSection = labeledCard("날짜", datePicker)

        let stack = UIStackView(arrangedSubviews: [
            makeFieldLabel("카테고리"), chipRow,
            makeFieldLabel("태그"), tagPicker,
            spacer(8), amountLabel, quickRow,
            spacer(8), memoSection, dateSection,
        ])
        stack.axis = .vertical
        stack.spacing = Theme.Space.sm
        stack.setCustomSpacing(Theme.Space.lg, after: chipRow)
        stack.setCustomSpacing(Theme.Space.md, after: amountLabel)
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
            quickRow.heightAnchor.constraint(equalToConstant: 38),

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
    /// 라벨 + 카드 배경에 감싼 콘텐츠 (메모·날짜 공통 스타일)
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
    private func makeQuickButton(_ amount: Int) -> UIButton {
        let b = UIButton(type: .system)
        b.setTitle("+\(amount.grouped)", for: .normal)
        b.titleLabel?.font = Theme.Font.caption(13)
        b.setTitleColor(Theme.Color.point, for: .normal)
        b.backgroundColor = Theme.Color.groupedBG
        b.layer.cornerRadius = 8
        b.layer.cornerCurve = .continuous
        b.addAction(UIAction { [weak self] _ in self?.bump(amount) }, for: .touchUpInside)
        return b
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
    private func prefill(_ e: Expense) {
        selectedCategory = e.category
        amountValue = e.amount
        memoField.text = e.memo
        datePicker.date = e.date
        chips.forEach { $0.isSelected = ($0.category == e.category) }
        hiddenField.text = "\(e.amount)"
        selectedTags = e.tags
        isFixed = e.isFixed
        tagPicker.configure(for: e.category, preselected: e.tags, isFixed: e.isFixed)    }

    @objc private func chipTapped(_ chip: CategoryChip) {
        Haptic.selection()
        selectedCategory = chip.category
        // 캐시에 저장된 태그가 있으면 복원, 없으면 빈 상태
        let cached = tagCache[selectedCategory]
        selectedTags = cached?.tags ?? []
        isFixed = cached?.isFixed ?? false
        tagPicker.configure(for: selectedCategory, preselected: selectedTags, isFixed: isFixed)
        UIView.animate(withDuration: 0.2) {
            self.chips.forEach { $0.isSelected = ($0 === chip) }
        }
    }

    @objc private func focusAmount() { hiddenField.becomeFirstResponder() }

    @objc private func amountTyping() {
        let digits = (hiddenField.text ?? "").filter(\.isNumber)
        let trimmed = String(digits.prefix(9))           // 9자리 제한
        hiddenField.text = trimmed
        amountValue = Int(trimmed) ?? 0
        refresh()
    }

    private func bump(_ amount: Int) {
        Haptic.light()
        amountValue = min(amountValue + amount, 999_999_999)
        hiddenField.text = "\(amountValue)"
        refresh()
        amountLabel.transform = CGAffineTransform(scaleX: 1.06, y: 1.06)
        UIView.animate(withDuration: 0.2) { self.amountLabel.transform = .identity }
    }

    private func refresh() {
        amountLabel.text = amountValue.won
        amountLabel.textColor = amountValue > 0 ? Theme.Color.mainText : Theme.Color.tertiaryText
        // 버튼은 항상 누를 수 있게 두고, 빈 금액이면 흔들림으로 안내 (alpha로만 비활성 느낌)
        saveButton.alpha = amountValue > 0 ? 1 : 0.45
    }

    @objc private func save() {
        guard !isSaving else { return }
        // 빈 금액 — 저장 막고 흔들림 + 안내
        guard amountValue > 0 else {
            Haptic.warning()
            shakeAmount()
            Toast.show("금액을 입력해주세요", style: Toast.Style.info, in: view, duration: 1.4)
            focusAmount()
            return
        }
        isSaving = true
        saveButton.isEnabled = false

        Haptic.success()
        let expense = Expense(
            id: editingExpanse?.id ?? UUID(),
            category: selectedCategory,
            amount: amountValue,
            memo: memoField.text?.trimmingCharacters(in: .whitespaces) ?? "",
            date: datePicker.date,
            tags: selectedTags,
            isFixed: isFixed)
        TagLibrary.record(selectedTags, for: selectedCategory)
        if editingExpanse == nil { ExpenseStore.shared.add(expense) }
        else { ExpenseStore.shared.update(expense) }
        dismiss(animated: true) { [weak self] in self?.onSaved?() }
    }

    /// 금액 라벨 좌우 흔들기 (빈 금액 저장 시도 피드백)
    private func shakeAmount() {
        let anim = CAKeyframeAnimation(keyPath: "transform.translation.x")
        anim.values = [-10, 10, -8, 8, -4, 4, 0]
        anim.duration = 0.4
        amountLabel.layer.add(anim, forKey: "shake")
    }

    @objc private func close() { dismiss(animated: true) }

    @objc private func dismissKeyboard() { view.endEditing(true) }
}

extension AddViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ tf: UITextField) -> Bool { tf.resignFirstResponder(); return true }
}

extension AddViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ g: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard let v = touch.view else { return true }
        if v.isDescendant(of: amountLabel) || v is UIControl || v is UITextField { return false }
        return true
    }
}
