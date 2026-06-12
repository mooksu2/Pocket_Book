// ViewControllers/ListViewController.swift
import UIKit

final class ListViewController: UIViewController {

    private var year = Date().year
    private var month = Date().month
    private var sections: [DaySection] = []
    private var searchText = ""
    private var categoryFilter: Category?

    // MARK: Header
    private lazy var monthButton: UIButton = {
        let b = UIButton(type: .system)
        b.titleLabel?.font = Theme.Font.title(16)
        b.tintColor = Theme.Color.mainText
        b.setTitleColor(Theme.Color.mainText, for: .normal)
        return b
    }()
    private let prevButton = ListViewController.navButton("chevron.left")
    private let nextButton = ListViewController.navButton("chevron.right")
    
    private let todayButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.title = "이번 달로 이동"
        config.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 10, bottom: 5, trailing: 10)
        config.baseForegroundColor = Theme.Color.point
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer {
            var a = $0; a.font = Theme.Font.caption(12); return a
        }
        let b = UIButton(configuration: config)
        b.backgroundColor = Theme.Color.pointSoft   // 테두리 → 틴트 (새 칩 언어와 통일)
        b.layer.cornerRadius = 12
        b.layer.cornerCurve = .continuous
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()
    
    private let totalCaption: UILabel = {
        let l = UILabel()
        l.text = "이번 달 지출"
        l.font = Theme.Font.caption(13)
        l.textColor = Theme.Color.subText
        l.textAlignment = .left
        return l
    }()
    
    private let totalLabel: AnimatedCountLabel = {
        let l = AnimatedCountLabel()
        l.font = Theme.Font.display(44)
        l.textColor = Theme.Color.mainText
        l.textAlignment = .left
        l.adjustsFontSizeToFitWidth = true
        l.minimumScaleFactor = 0.5
        return l
    }()

    // MARK: 지난달 대비 비교
    private let comparisonLabel: UILabel = {
        let l = UILabel()
        l.font = Theme.Font.caption(13)
        l.textAlignment = .left
        l.adjustsFontSizeToFitWidth = true
        l.minimumScaleFactor = 0.8
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // MARK: Insight strip
    private let insightView: UIView = {
        let v = UIView()
        v.backgroundColor = .clear
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()
    private let insightLabel: UILabel = {
        let l = UILabel()
        l.font = Theme.Font.body(13)
        l.textColor = Theme.Color.subText
        l.numberOfLines = 1
        l.adjustsFontSizeToFitWidth = true
        l.minimumScaleFactor = 0.8
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // MARK: Budget (P3)
    private let budgetView = BudgetProgressView()

    // MARK: Search & Filter
    private let filterBar = CategoryFilterBar()

    private let tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .plain)
        tv.register(ExpenseCell.self, forCellReuseIdentifier: ExpenseCell.reuseID)
        tv.separatorStyle = .none
        tv.backgroundColor = .clear
        tv.rowHeight = UITableView.automaticDimension
        tv.estimatedRowHeight = 64
        tv.showsVerticalScrollIndicator = false
        tv.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 12, right: 0)   // 탭바 회피는 additionalSafeAreaInsets가 처리
        return tv
    }()
    private lazy var emptyView = EmptyStateView(
        symbol: "tray", title: "이번 달 지출이 없어요",
        subtitle: "오른쪽 아래 + 버튼을 눌러\n첫 지출을 기록해 보세요")

    private lazy var addButton: UIButton = {
        let b = UIButton(type: .custom)
        b.setImage(UIImage(systemName: "plus",
                           withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .bold)), for: .normal)
        b.tintColor = .white
        b.backgroundColor = Theme.Color.point
        b.layer.cornerRadius = 29          // 58/2 → 원형
        b.layer.cornerCurve = .continuous
        b.translatesAutoresizingMaskIntoConstraints = false
        Theme.applyCardShadow(to: b.layer, opacity: 0.35, radius: 12, y: 6)
        b.layer.shadowColor = Theme.Color.point.cgColor
        return b
    }()

    // MARK: 고정지출 진입 (Fixed-expense entry)
    private let fixedRow: UIControl = {
        let v = UIControl()
        v.backgroundColor = Theme.Color.pointSoft
        v.layer.cornerRadius = Theme.Radius.sm
        v.layer.cornerCurve = .continuous
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()
    private let fixedTitleLabel: UILabel = {
        let l = UILabel()
        l.text = "고정지출"
        l.font = Theme.Font.caption(13)
        l.textColor = Theme.Color.point
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    private let fixedAmountLabel: UILabel = {
        let l = UILabel()
        l.font = Theme.Font.money(14, .semibold)
        l.textColor = Theme.Color.point
        l.textAlignment = .right
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    private let fixedActionLabel: UILabel = {
        let l = UILabel()
        l.font = Theme.Font.caption(13)
        l.textColor = Theme.Color.subText
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    private let fixedChevron: UIImageView = {
        let iv = UIImageView(image: UIImage(systemName: "chevron.right",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)))
        iv.tintColor = Theme.Color.point
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private static func navButton(_ symbol: String) -> UIButton {
        let b = UIButton(type: .system)
        b.setImage(UIImage(systemName: symbol,
                           withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)), for: .normal)
        b.tintColor = Theme.Color.point
        return b
    }

    // MARK: Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.Color.background
        buildLayout()
        title = "기록"
        wireActions()

        filterBar.onSearchChanged = { [weak self] text in
            self?.searchText = text
            self?.reload(animatedTotal: false)
        }
        filterBar.onSelect = { [weak self] cat in
            self?.categoryFilter = cat
            self?.reload(animatedTotal: false)
        }

        NotificationCenter.default.addObserver(self, selector: #selector(reloadOnChange),
                                               name: .expensesDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadOnChange),
                                               name: .settingsDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadOnChange),
                                               name: .recurringDidChange, object: nil)
        reload(animatedTotal: true)
    }

    // MARK: Layout
    private func buildLayout() {
        // 월 내비: 대칭형 컨트롤이라 정중앙 배치 (내비 존 = 가운데 / 콘텐츠 존 = 좌측 히어로)
        let monthGroup = UIStackView(arrangedSubviews: [prevButton, monthButton, nextButton])
        monthGroup.alignment = .center
        monthGroup.spacing = Theme.Space.sm
        monthGroup.translatesAutoresizingMaskIntoConstraints = false

        let navRow = UIView()
        navRow.translatesAutoresizingMaskIntoConstraints = false
        navRow.addSubview(monthGroup)
        navRow.addSubview(todayButton)
        todayButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            monthGroup.centerXAnchor.constraint(equalTo: navRow.centerXAnchor),
            monthGroup.topAnchor.constraint(equalTo: navRow.topAnchor),
            monthGroup.bottomAnchor.constraint(equalTo: navRow.bottomAnchor),
            todayButton.trailingAnchor.constraint(equalTo: navRow.trailingAnchor),
            todayButton.centerYAnchor.constraint(equalTo: navRow.centerYAnchor),
        ])

        insightView.addSubview(insightLabel)
        fixedRow.addSubview(fixedTitleLabel)
        fixedRow.addSubview(fixedAmountLabel)
        fixedRow.addSubview(fixedActionLabel)
        fixedRow.addSubview(fixedChevron)
        budgetView.translatesAutoresizingMaskIntoConstraints = false
        let header = UIStackView(arrangedSubviews: [navRow, totalCaption, totalLabel, comparisonLabel, budgetView, insightView, fixedRow])
        header.axis = .vertical
        header.alignment = .fill
        header.spacing = Theme.Space.xs
        header.setCustomSpacing(Theme.Space.md, after: navRow)
        header.setCustomSpacing(Theme.Space.sm, after: totalLabel)
        header.setCustomSpacing(Theme.Space.lg, after: comparisonLabel)
        header.setCustomSpacing(Theme.Space.lg, after: budgetView)
        header.setCustomSpacing(Theme.Space.sm, after: insightView)
        header.translatesAutoresizingMaskIntoConstraints = false
        header.isLayoutMarginsRelativeArrangement = true
        header.layoutMargins = UIEdgeInsets(top: Theme.Space.md, left: Theme.Space.lg,
                                            bottom: Theme.Space.md, right: Theme.Space.lg)

        view.addSubview(header)
        view.addSubview(filterBar)
        view.addSubview(tableView)
        view.addSubview(emptyView)
        view.addSubview(addButton)

        tableView.dataSource = self
        tableView.delegate = self
        tableView.translatesAutoresizingMaskIntoConstraints = false
        emptyView.translatesAutoresizingMaskIntoConstraints = false
        filterBar.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            insightView.heightAnchor.constraint(equalToConstant: 22),
            insightView.leadingAnchor.constraint(equalTo: header.layoutMarginsGuide.leadingAnchor),
            insightView.trailingAnchor.constraint(equalTo: header.layoutMarginsGuide.trailingAnchor),
            insightLabel.leadingAnchor.constraint(equalTo: insightView.leadingAnchor),
            insightLabel.trailingAnchor.constraint(equalTo: insightView.trailingAnchor),
            insightLabel.centerYAnchor.constraint(equalTo: insightView.centerYAnchor),

            fixedRow.heightAnchor.constraint(equalToConstant: 44),
            fixedRow.leadingAnchor.constraint(equalTo: header.layoutMarginsGuide.leadingAnchor),
            fixedRow.trailingAnchor.constraint(equalTo: header.layoutMarginsGuide.trailingAnchor),
            fixedTitleLabel.leadingAnchor.constraint(equalTo: fixedRow.leadingAnchor, constant: Theme.Space.md),
            fixedTitleLabel.centerYAnchor.constraint(equalTo: fixedRow.centerYAnchor),
            fixedChevron.trailingAnchor.constraint(equalTo: fixedRow.trailingAnchor, constant: -Theme.Space.md),
            fixedChevron.centerYAnchor.constraint(equalTo: fixedRow.centerYAnchor),
            fixedActionLabel.trailingAnchor.constraint(equalTo: fixedChevron.leadingAnchor, constant: -Theme.Space.xs),
            fixedActionLabel.centerYAnchor.constraint(equalTo: fixedRow.centerYAnchor),
            fixedAmountLabel.trailingAnchor.constraint(equalTo: fixedActionLabel.leadingAnchor, constant: -Theme.Space.sm),
            fixedAmountLabel.centerYAnchor.constraint(equalTo: fixedRow.centerYAnchor),

            // 큰 금액이 화면을 넘지 않도록 폭 제한 → adjustsFontSizeToFitWidth 동작
            totalLabel.widthAnchor.constraint(lessThanOrEqualTo: header.layoutMarginsGuide.widthAnchor),
            totalCaption.widthAnchor.constraint(lessThanOrEqualTo: header.layoutMarginsGuide.widthAnchor),

            budgetView.leadingAnchor.constraint(equalTo: header.layoutMarginsGuide.leadingAnchor),
            budgetView.trailingAnchor.constraint(equalTo: header.layoutMarginsGuide.trailingAnchor),

            comparisonLabel.widthAnchor.constraint(lessThanOrEqualTo: header.layoutMarginsGuide.widthAnchor),

            filterBar.topAnchor.constraint(equalTo: header.bottomAnchor, constant: Theme.Space.xs),
            filterBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            filterBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            filterBar.heightAnchor.constraint(equalToConstant: 40),

            tableView.topAnchor.constraint(equalTo: filterBar.bottomAnchor, constant: Theme.Space.xs),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyView.topAnchor.constraint(equalTo: tableView.topAnchor),
            emptyView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            emptyView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            emptyView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            addButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Theme.Space.xl),
            addButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -Theme.Space.xl),
            addButton.widthAnchor.constraint(equalToConstant: 58),
            addButton.heightAnchor.constraint(equalToConstant: 58),
        ])
    }

    private func wireActions() {
        prevButton.addTarget(self, action: #selector(prevMonth), for: .touchUpInside)
        nextButton.addTarget(self, action: #selector(nextMonth), for: .touchUpInside)
        monthButton.addTarget(self, action: #selector(showMonthPicker), for: .touchUpInside)
        todayButton.addTarget(self, action: #selector(jumpToToday), for: .touchUpInside)
        addButton.addTarget(self, action: #selector(addDown), for: .touchDown)
        addButton.addTarget(self, action: #selector(addUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        addButton.addTarget(self, action: #selector(openAdd), for: .touchUpInside)
        fixedRow.addTarget(self, action: #selector(openFixed), for: .touchUpInside)
    }

    @objc private func openFixed() {
        Haptic.medium()
        let vc = RecurringListViewController()
        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .pageSheet
        present(nav, animated: true)
    }

    // MARK: Data
    @objc private func reloadOnChange() { reload(animatedTotal: true) }

    private func reload(animatedTotal: Bool) {
        let allSections = ExpenseStore.shared.daySections(year: year, month: month)
        let total = ExpenseStore.shared.totalAmount(year: year, month: month)
        let insight = ExpenseStore.shared.insight(year: year, month: month)

        monthButton.setTitle("\(year)년 \(month)월", for: .normal)
        updateTodayButton()
        totalLabel.setValue(total, animated: animatedTotal)

        // 고정지출 진입 줄 — 이번 달 고정지출 총액 + 액션
        let fixedTotal = RecurringStore.shared.monthlyTotal()
        fixedAmountLabel.text = fixedTotal.won
        fixedActionLabel.text = RecurringStore.shared.items.isEmpty ? "등록하기" : "관리"

        // 예산 진행바 (P3)
        if let status = ExpenseStore.shared.budgetStatus(year: year, month: month) {
            budgetView.isHidden = false
            budgetView.configure(status, animated: animatedTotal)
            // 현재 달일 때만 초과 알림 평가
            if year == Date().year && month == Date().month {
                NotificationService.evaluateBudget(status)
            }
        } else {
            budgetView.isHidden = true
        }

        // 지난달 대비 비교
        configureComparison()

        // 인사이트
        if insight.entryCount > 0 {
            insightView.isHidden = false
            insightLabel.text = "💡 \(insight.headline) · 하루 평균 \(insight.dailyAverage.won)"
        } else {
            insightView.isHidden = true
        }

        // 검색·필터 적용 (리스트만, 상단 요약은 월 전체 기준 유지)
        sections = filteredSections(from: allSections)
        let fullEmpty = allSections.isEmpty
        let filteredEmpty = sections.isEmpty
        if fullEmpty {
            emptyView.update(symbol: "tray",
                             title: "이번 달 지출이 없어요",
                             subtitle: "오른쪽 아래 + 버튼을 눌러\n첫 지출을 기록해 보세요")
        } else if filteredEmpty {
            emptyView.update(symbol: "magnifyingglass",
                             title: "조건에 맞는 지출이 없어요",
                             subtitle: "검색어나 카테고리 필터를 바꿔 보세요")
        }
        emptyView.isHidden = !(fullEmpty || filteredEmpty)
        tableView.isHidden = fullEmpty || filteredEmpty
        tableView.reloadData()
    }

    /// 카테고리 필터 + 검색어를 적용해 섹션을 추린다.
    private func filteredSections(from all: [DaySection]) -> [DaySection] {
        let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard categoryFilter != nil || !q.isEmpty else { return all }
        return all.compactMap { sec in
            let items = sec.expenses.filter { e in
                let catOK = (categoryFilter == nil) || (e.category == categoryFilter)
                let textOK = q.isEmpty
                    || e.memo.lowercased().contains(q)
                    || e.category.rawValue.lowercased().contains(q)
                    || e.tags.contains { $0.lowercased().contains(q) }
                    || (e.isFixed && "고정지출".contains(q))
                return catOK && textOK
            }
            return items.isEmpty ? nil : DaySection(date: sec.date, expenses: items)
        }
    }

    /// 지난달 같은 기간 대비 증감을 라벨에 표시.
    private func configureComparison() {
        let cmp = ExpenseStore.shared.comparison(year: year, month: month)
        guard cmp.hasPrevious else { comparisonLabel.isHidden = true; return }
        comparisonLabel.isHidden = false
        let period = cmp.isCurrentMonth ? "지난달 같은 기간보다" : "지난달보다"
        if cmp.isFlat {
            comparisonLabel.text = "지난달과 비슷해요"
            comparisonLabel.textColor = Theme.Color.subText
        } else if cmp.isUp {
            comparisonLabel.text = "▲ \(period) \(cmp.percent)% 더 썼어요"
            comparisonLabel.textColor = .systemRed
        } else {
            comparisonLabel.text = "▼ \(period) \(cmp.percent)% 덜 썼어요"
            comparisonLabel.textColor = .systemGreen
        }
    }

    // MARK: Actions
    @objc private func prevMonth() { shiftMonth(-1) }
    @objc private func nextMonth() { shiftMonth(+1) }

    private func shiftMonth(_ delta: Int) {
        Haptic.selection()
        var c = DateComponents(); c.year = year; c.month = month + delta
        if let d = Calendar.current.date(from: c) {
            year = d.year; month = d.month
            reload(animatedTotal: true)
            // 헤더 방향 전환 페이드
            tableView.transform = CGAffineTransform(translationX: delta > 0 ? 20 : -20, y: 0)
            tableView.alpha = 0.4
            UIView.animate(withDuration: 0.25) {
                self.tableView.transform = .identity
                self.tableView.alpha = 1
            }
        }
    }

    @objc private func jumpToToday() {
        Haptic.light()
        year = Date().year; month = Date().month
        reload(animatedTotal: true)
    }
    
    @objc private func showMonthPicker() {
        Haptic.selection()
        let vc = MonthPickerViewController(year: year, month: month)
        vc.onSelect = { [weak self] y, m in
            guard let self = self else { return }
            self.year = y; self.month = m
            self.reload(animatedTotal: false)
        }
        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .pageSheet
        present(nav, animated: true)
    }

    private func updateTodayButton() {
        let t = Date()
        todayButton.isHidden = (year == t.year && month == t.month)
    }
    
    @objc private func addDown() { addButton.pressDown() }
    @objc private func addUp()   { addButton.pressUp() }

    @objc private func openAdd() {
        Haptic.medium()
        presentEditor(for: nil, successMessage: "저장되었습니다")
    }

    private func presentEditor(for expense: Expense?, successMessage: String) {
        let vc = AddViewController(editing: expense)
        vc.onSaved = { [weak self] in
            guard let self else { return }
            Toast.show(successMessage, style: .success, in: self.view)
        }
        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .pageSheet
        present(nav, animated: true)
    }

}

// MARK: - DataSource / Delegate
extension ListViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int { sections.count }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].expenses.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ExpenseCell.reuseID, for: indexPath) as! ExpenseCell
        cell.configure(with: sections[indexPath.section].expenses[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = SectionHeaderView()
        let s = sections[section]
        header.configure(date: s.date, total: s.total)
        return header
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat { 38 }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        Haptic.light()
        let expense = sections[indexPath.section].expenses[indexPath.row]
        presentEditor(for: expense, successMessage: "수정되었습니다")
    }

    func tableView(_ tableView: UITableView,
                   trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        let expense = sections[indexPath.section].expenses[indexPath.row]

        // 고정지출 자동 생성분: 오렌지 "이번 달 건너뛰기" — 재진입 시 재생성이 의도된 동작
        // 일반 지출: 빨간 "삭제" — 영구 삭제
        let isAutoGenerated = expense.recurringID != nil
        let action = UIContextualAction(style: .destructive, title: nil) { [weak self] _, _, done in
            self?.deleteWithUndo(expense)
            done(true)
        }
        action.image = UIImage(systemName: isAutoGenerated ? "calendar.badge.minus" : "trash.fill")
        action.backgroundColor = isAutoGenerated ? .systemOrange : .systemRed
        return UISwipeActionsConfiguration(actions: [action])
    }

    /// 즉시 삭제 후 되돌리기 토스트.
    /// - 고정지출 자동 생성분: skipMonth 마킹(재생성 방지) / Undo → unskip(재생성 허용)
    /// - 일반 지출: 영구 삭제 / Undo → 동일 id 복원
    private func deleteWithUndo(_ expense: Expense) {
        Haptic.medium()
        let snapshot = Expense(
            id: expense.id,
            category: expense.category,
            amount: expense.amount,
            memo: expense.memo,
            date: expense.date,
            tags: expense.tags,
            isFixed: expense.isFixed,
            recurringID: expense.recurringID)

        ExpenseStore.shared.delete(id: expense.id)   // recurringID 있으면 내부에서 skipMonth 호출

        let message = expense.recurringID != nil ? "이번 달 건너뛰었어요" : "지출이 삭제됐어요"
        Toast.showWithAction(message, actionTitle: "되돌리기", in: view) {
            Haptic.success()
            ExpenseStore.shared.add(snapshot)   // recurringID 있으면 내부에서 unskipMonth 호출
        }
    }
}
