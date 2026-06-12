import UIKit

/// 고정지출 등록·수정 폼. 메모 / 금액 / 카테고리 / 매월 며칠.
final class RecurringEditViewController: UIViewController {

    var onSaved: (() -> Void)?

    private let editingItem: RecurringExpense?
    private var selectedCategory: Category = .food
    private var chips: [CategoryChip] = []
    private var dayOfMonth = 1
    private var isSaving = false
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
    /// 금액 입력 블록 (₩라벨 + 키패드 + 퀵버튼) — 지출 입력 화면과 공유
    private let amountInput = AmountInputView()
    private let dayValueLabel: UILabel = {
        let l = UILabel()
        l.text = "매월 1일"
        l.font = Theme.Font.title(16)
        l.textColor = Theme.Color.mainText
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    /// 결제일 선택 버튼 (탭하면 휠 피커 시트)
    private let dayChevron: UIImageView = {
        let iv = UIImageView(image: UIImage(systemName: "chevron.up.chevron.down"))
        iv.tintColor = Theme.Color.point
        iv.contentMode = .scaleAspectFit
        iv.preferredSymbolConfiguration = .init(pointSize: 13, weight: .semibold)
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
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
        amountInput.onChanged = { [weak self] amount in
            // 버튼은 항상 누를 수 있게 두고, 빈 금액이면 alpha로만 비활성 느낌
            self?.saveButton.alpha = amount > 0 ? 1 : 0.45
        }
        nameField.delegate = self

        tagPicker.setFixedToggleHidden(true)   // 고정지출 화면이라 토글 불필요, 태그만 사용

        // 빈 곳 탭 → 키패드 내리기 (금액 라벨·컨트롤 위 탭은 제외)
        let tapToDismiss = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapToDismiss.cancelsTouchesInView = false
        tapToDismiss.delegate = self
        view.addGestureRecognizer(tapToDismiss)

        // 수정 모드면 안내 힌트 노출
        editHintLabel.isHidden = (editingItem == nil)

        if let it = editingItem { prefill(it) } else {
            tagPicker.configure(for: selectedCategory)
            amountInput.setAmount(0)   // 초기 상태 동기화
        }
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

        // 결제일 행: 좌측 라벨 + 우측 chevron (탭하면 휠 피커)
        let daySpacer = UIView()
        daySpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let dayRow = UIStackView(arrangedSubviews: [dayValueLabel, daySpacer, dayChevron])
        dayRow.axis = .horizontal
        dayRow.alignment = .center
        dayRow.spacing = Theme.Space.sm
        dayRow.isUserInteractionEnabled = true
        let dayTap = UITapGestureRecognizer(target: self, action: #selector(openDayPicker))
        dayRow.addGestureRecognizer(dayTap)

        let nameSection = labeledCard("메모", nameField)
        let daySection  = labeledCard("결제일 (매월)", dayRow)

        let amountSeparator = UIView()
        amountSeparator.backgroundColor = Theme.Color.hairline
        amountSeparator.translatesAutoresizingMaskIntoConstraints = false

        // 순서: 카테고리 → 태그 → 구분선 → 금액 → 퀵버튼 → 메모 → 결제일 → 힌트
        let stack = UIStackView(arrangedSubviews: [
            makeFieldLabel("카테고리"), chipRow,
            makeFieldLabel("태그"), tagPicker,
            amountSeparator, amountInput,
            nameSection, daySection,
            editHintLabel,
        ])
        stack.axis = .vertical
        stack.spacing = Theme.Space.sm
        stack.setCustomSpacing(Theme.Space.lg, after: chipRow)
        stack.setCustomSpacing(Theme.Space.lg, after: tagPicker)
        stack.setCustomSpacing(Theme.Space.lg, after: amountInput)
        stack.setCustomSpacing(Theme.Space.md, after: daySection)
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(scrollView)
        scrollView.addSubview(stack)
        view.addSubview(saveButton)
        saveButton.addTarget(self, action: #selector(save), for: .touchUpInside)

        NSLayoutConstraint.activate([
            // 스크롤 영역은 항상 저장 버튼 위에서 끝난다 → 포커스된 필드가 버튼에 가려지지 않는다
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: saveButton.topAnchor, constant: -Theme.Space.sm),

            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: Theme.Space.xl),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: Theme.Space.lg),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -Theme.Space.lg),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -Theme.Space.md),
            stack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -2 * Theme.Space.lg),
            chipRow.heightAnchor.constraint(equalToConstant: 64),
            amountSeparator.heightAnchor.constraint(equalToConstant: 1),

            saveButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Theme.Space.lg),
            saveButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Theme.Space.lg),
            // 키보드가 없으면 safe area 하단, 올라오면 키보드 위 — 시스템이 애니메이션까지 처리
            saveButton.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor, constant: -Theme.Space.md),
            saveButton.heightAnchor.constraint(equalToConstant: 54),
        ])
    }

    // MARK: Builders
    private func makeFieldLabel(_ t: String) -> UILabel {
        let l = UILabel(); l.text = t
        l.font = Theme.Font.caption(13); l.textColor = Theme.Color.subText
        return l
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

    // MARK: Logic
    private func prefill(_ it: RecurringExpense) {
        selectedCategory = it.category
        amountInput.setAmount(it.amount)
        nameField.text = it.name
        dayOfMonth = it.dayOfMonth
        dayValueLabel.text = "매월 \(it.dayOfMonth)일"
        chips.forEach { $0.isSelected = ($0.category == it.category) }
        tagPicker.configure(for: it.category, preselected: it.tags)
    }

    /// 카테고리 전환 시 태그 선택을 보관했다가 돌아오면 복원 (지출 입력 화면과 동일 UX)
    private var tagCache: [Category: [String]] = [:]

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

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if editingItem == nil { amountInput.focus() }   // 신규 등록 즉시 키패드
    }

    /// 결제일 휠 피커 시트 — 1~31일을 한 번에 스크롤 선택
    @objc private func openDayPicker() {
        Haptic.selection()
        view.endEditing(true)
        let picker = DayPickerSheet(selected: dayOfMonth) { [weak self] day in
            guard let self else { return }
            self.dayOfMonth = day
            self.dayValueLabel.text = "매월 \(day)일"
            Haptic.selection()
        }
        picker.modalPresentationStyle = .pageSheet
        if let sheet = picker.sheetPresentationController {
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = true
        }
        present(picker, animated: true)
    }

    @objc private func save() {
        guard !isSaving else { return }
        guard amountInput.amount > 0 else {
            Haptic.warning()
            amountInput.shake()
            Toast.show("금액을 입력해주세요", style: Toast.Style.info, in: view, duration: 1.4)   // in: view → keyboardLayoutGuide로 키패드 위에 표시
            amountInput.focus()
            return
        }
        isSaving = true
        saveButton.isEnabled = false

        let name = nameField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        Haptic.success()

        if let target = editingItem {
            // 편집 도중 다른 경로로 삭제된 규칙이면 조용히 부활시키지 않는다
            // (modelContext nil 체크는 iOS 17에서 정상 객체에도 nil을 반환할 수 있어 스토어 캐시로 판별)
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

    @objc private func dismissKeyboard() { view.endEditing(true) }
}

extension RecurringEditViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ g: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard let v = touch.view else { return true }
        // 금액 라벨·버튼·스위치·텍스트필드 위 탭은 무시 (키패드 토글 충돌 방지)
        if v.isDescendant(of: amountInput) || v is UIControl || v is UITextField { return false }
        return true
    }
}

extension RecurringEditViewController: UITextFieldDelegate {
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
