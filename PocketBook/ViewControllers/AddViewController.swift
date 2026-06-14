// ViewControllers/AddViewController.swift
import UIKit

final class AddViewController: CardFormViewController {

    var onSaved: (() -> Void)?
    private var editingExpense: Expense?
    private var isSaving = false
    private var selectedCategory: Category = .food
    private var chips: [CategoryChip] = []
    private var selectedTags: [String] = []
    /// 카테고리별 태그 임시 캐시 — 칩 전환 시 입력 유지
    private var tagCache: [Category: [String]] = [:]
    private let tagPicker = TagPickerView()

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
    /// 자동 생성된 고정지출분을 수정할 때 날짜 변경을 막고 안내한다 (2-F)
    private let dateLockHint: UILabel = {
        let l = UILabel()
        l.font = Theme.Font.caption(12)
        l.textColor = Theme.Color.subText
        l.numberOfLines = 0
        l.text = "ℹ️ 고정지출 결제일은 '고정지출 관리'에서 바꿔주세요."
        l.isHidden = true
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // MARK: Init
    init(editing expense: Expense?) {
        self.editingExpense = expense
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()   // 스캐폴드(scroll + saveButton + 제스처) 구성
        title = editingExpense == nil ? "지출 등록" : "지출 수정"
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close, target: self, action: #selector(close))

        protectedTapView = amountInput   // 금액 영역 탭은 키패드 토글로 처리

        tagPicker.configure(for: selectedCategory)
        tagPicker.onChanged = { [weak self] tags in
            guard let self else { return }
            self.selectedTags = tags
            self.tagCache[self.selectedCategory] = tags   // 캐시 동기화
        }
        amountInput.onChanged = { [weak self] amount in
            // 버튼은 항상 누를 수 있게 두고, 빈 금액이면 alpha로만 비활성 느낌
            self?.saveButton.alpha = amount > 0 ? 1 : 0.45
        }
        memoField.delegate = self

        if let e = editingExpense { prefill(e) } else { amountInput.setAmount(0) }   // 초기 상태 동기화
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if editingExpense == nil { amountInput.focus() } // 입력 즉시 키패드
    }

    // MARK: Form body
    override func makeFormStack() -> UIStackView {
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

        // 1) 금액 히어로 — 카드 없이 회색 배경에 직접
        amountInput.caption = "얼마를 쓰셨나요?"

        // 2) 카테고리 카드
        let catCard = card()
        let catStack = UIStackView(arrangedSubviews: [makeFieldLabel("카테고리"), chipRow])
        catStack.axis = .vertical; catStack.spacing = Theme.Space.sm
        embed(catStack, in: catCard)

        // 3) 태그 카드
        let tagCard = card()
        let tagStack = UIStackView(arrangedSubviews: [makeFieldLabel("태그"), tagPicker])
        tagStack.axis = .vertical; tagStack.spacing = Theme.Space.sm
        embed(tagStack, in: tagCard)

        // 4) 옵션 카드 — 날짜 / 메모 (고정 토글은 제거 — '고정지출'은 반복 규칙으로 일원화)
        let optionCard = card()
        dateButton.addTarget(self, action: #selector(dateTapped), for: .touchUpInside)
        dateButton.addTarget(self, action: #selector(dateButtonDown), for: [.touchDown, .touchDragEnter])
        dateButton.addTarget(self, action: #selector(dateButtonUp), for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])
        updateDateButton()
        let dateRow = optionRow("날짜", dateButton)
        memoField.textAlignment = .right
        let memoRow = optionRow("메모", memoField)
        let optStack = UIStackView(arrangedSubviews: [dateRow, hairline(), memoRow])
        optStack.axis = .vertical; optStack.spacing = Theme.Space.md
        embed(optStack, in: optionCard)

        let stack = UIStackView(arrangedSubviews: [amountInput, catCard, tagCard, optionCard, dateLockHint])
        stack.axis = .vertical
        stack.spacing = Theme.Space.md
        stack.setCustomSpacing(Theme.Space.xl, after: amountInput)   // 히어로 아래 넉넉히
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: Theme.Space.xl, left: 0, bottom: 0, right: 0)
        return stack
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
        tagPicker.configure(for: e.category, preselected: e.tags)
        tagCache[e.category] = e.tags

        // 자동 생성된 고정지출분은 날짜 잠금 (2-F)
        if e.recurringID != nil {
            dateButton.isEnabled = false
            dateButton.configuration?.baseForegroundColor = Theme.Color.tertiaryText
            dateLockHint.isHidden = false
        }
    }

    @objc private func chipTapped(_ chip: CategoryChip) {
        Haptic.selection()
        selectedCategory = chip.category
        // 캐시에 저장된 태그가 있으면 복원, 없으면 빈 상태
        selectedTags = tagCache[selectedCategory] ?? []
        tagPicker.configure(for: selectedCategory, preselected: selectedTags)
        UIView.animate(withDuration: 0.2) {
            self.chips.forEach { $0.isSelected = ($0 === chip) }
        }
    }

    override func didTapSave() {
        guard !isSaving else { return }
        // 빈 금액 — 저장 막고 흔들림 + 안내
        guard amountInput.amount > 0 else {
            Haptic.warning()
            amountInput.shake()
            Toast.show("금액을 입력해주세요", style: Toast.Style.info, in: view, duration: 1.4)
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
            guard ExpenseStore.shared.contains(id: target.id) else {
                ExpenseStore.shared.reloadFromDisk()
                dismiss(animated: true) { Toast.show("이미 삭제된 항목이에요", style: .info) }
                return
            }
            // live @Model 직접 수정 — recurringID·isFixed는 건드리지 않아 고정지출 링크가 보존된다
            target.category = selectedCategory
            target.amount   = amountInput.amount
            target.memo     = memo
            target.date     = selectedDate
            target.tags     = selectedTags
            ExpenseStore.shared.saveChanges()
        } else {
            // 수동 등록은 일회성 지출 — isFixed false (반복은 '고정지출 관리'에서만 생성)
            ExpenseStore.shared.add(Expense(
                category: selectedCategory,
                amount: amountInput.amount,
                memo: memo,
                date: selectedDate,
                tags: selectedTags,
                isFixed: false))
        }
        dismiss(animated: true) { [weak self] in self?.onSaved?() }
    }

    // MARK: Date row
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
        presentOnce(sheet)
    }

    private func updateDateButton() {
        dateButton.configuration?.title = Fmt.yyyyMd.string(from: selectedDate)
    }

    @objc private func close() { dismiss(animated: true) }
}
