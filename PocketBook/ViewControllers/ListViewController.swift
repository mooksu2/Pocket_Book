// ViewControllers/ListViewController.swift
import UIKit

final class ListViewController: UIViewController {

    private var year = Date().year
    private var month = Date().month
    private var sections: [DaySection] = []
    private var searchText = ""
    private var categoryFilter: Category?

    // MARK: Header
    private let monthNav = MonthNavigatorView()

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
        l.font = Theme.Font.display(36)
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
        let tv = UITableView(frame: .zero, style: .insetGrouped)   // 날짜별 흰 카드
        tv.register(ExpenseCell.self, forCellReuseIdentifier: ExpenseCell.reuseID)
        tv.separatorStyle = .singleLine
        tv.separatorColor = Theme.Color.hairline
        tv.separatorInset = UIEdgeInsets(top: 0, left: 64, bottom: 0, right: 16)
        tv.backgroundColor = .clear
        tv.sectionHeaderTopPadding = Theme.Space.xs
        tv.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: 0, leading: Theme.Space.lg, bottom: 0, trailing: Theme.Space.lg)
        tv.preservesSuperviewLayoutMargins = false
        tv.rowHeight = UITableView.automaticDimension
        tv.estimatedRowHeight = 64
        tv.showsVerticalScrollIndicator = false
        tv.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 12, right: 0)
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
        b.layer.cornerRadius = 29
        b.layer.cornerCurve = .continuous
        b.translatesAutoresizingMaskIntoConstraints = false
        Theme.applyCardShadow(to: b.layer, opacity: 0.35, radius: 12, y: 6)
        b.layer.shadowColor = Theme.Color.point.cgColor
        return b
    }()

    // MARK: 고정지출 진입 (Fixed-expense entry)
    private let fixedRow: UIControl = {
        let v = UIControl()
        v.backgroundColor = .clear
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()
    private let fixedIcon: UIView = {
        let v = UIView()
        v.backgroundColor = Theme.Color.pointSoft
        v.layer.cornerRadius = 12
        v.layer.cornerCurve = .continuous
        v.translatesAutoresizingMaskIntoConstraints = false
        let img = UIImageView(image: UIImage(systemName: "arrow.triangle.2.circlepath"))
        img.tintColor = Theme.Color.point
        img.contentMode = .center
        img.preferredSymbolConfiguration = .init(pointSize: 15, weight: .semibold)
        img.translatesAutoresizingMaskIntoConstraints = false
        v.addSubview(img)
        NSLayoutConstraint.activate([
            v.widthAnchor.constraint(equalToConstant: 38),
            v.heightAnchor.constraint(equalToConstant: 38),
            img.centerXAnchor.constraint(equalTo: v.centerXAnchor),
            img.centerYAnchor.constraint(equalTo: v.centerYAnchor),
        ])
        return v
    }()
    private let fixedSubLabel: UILabel = {
        let l = UILabel()
        l.text = "매달 빠져나가는 돈"
        l.font = Theme.Font.caption(12)
        l.textColor = Theme.Color.tertiaryText
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    /// 헤더 카드
    private let headerCard: CardView = {
        let v = CardView()
        return v
    }()
    private let insightDivider: UIView = {
        let v = UIView()
        v.backgroundColor = Theme.Color.hairline
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()
    private let fixedDivider: UIView = {
        let v = UIView()
        v.backgroundColor = Theme.Color.hairline
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

    // MARK: Lifecycle
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.Color.background
        buildLayout()
        title = ""
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
        insightView.addSubview(insightLabel)
        fixedRow.addSubview(fixedIcon)
        fixedRow.addSubview(fixedTitleLabel)
        fixedRow.addSubview(fixedSubLabel)
        fixedRow.addSubview(fixedAmountLabel)
        fixedRow.addSubview(fixedActionLabel)
        fixedRow.addSubview(fixedChevron)
        budgetView.translatesAutoresizingMaskIntoConstraints = false

        // 카드 안 콘텐츠: 요약 → 예산바 → (구분선) → 인사이트 → (구분선) → 고정지출
        let cardStack = UIStackView(arrangedSubviews: [
            totalCaption, totalLabel, comparisonLabel, budgetView,
            insightDivider, insightView, fixedDivider, fixedRow,
        ])
        cardStack.axis = .vertical
        cardStack.alignment = .fill
        cardStack.spacing = Theme.Space.xs
        cardStack.setCustomSpacing(Theme.Space.sm, after: totalLabel)
        cardStack.setCustomSpacing(Theme.Space.lg, after: comparisonLabel)
        cardStack.setCustomSpacing(Theme.Space.lg, after: budgetView)
        cardStack.setCustomSpacing(Theme.Space.sm, after: insightDivider)
        cardStack.setCustomSpacing(Theme.Space.sm, after: insightView)
        cardStack.setCustomSpacing(Theme.Space.md, after: fixedDivider)
        cardStack.translatesAutoresizingMaskIntoConstraints = false
        cardStack.isLayoutMarginsRelativeArrangement = true
        cardStack.layoutMargins = UIEdgeInsets(top: Theme.Space.lg, left: 20,
                                               bottom: Theme.Space.md, right: 20)
        headerCard.addSubview(cardStack)
        NSLayoutConstraint.activate([
            cardStack.topAnchor.constraint(equalTo: headerCard.topAnchor),
            cardStack.leadingAnchor.constraint(equalTo: headerCard.leadingAnchor),
            cardStack.trailingAnchor.constraint(equalTo: headerCard.trailingAnchor),
            cardStack.bottomAnchor.constraint(equalTo: headerCard.bottomAnchor),
        ])

        monthNav.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(tableView)
        view.addSubview(monthNav)    // 월 네비게이션 (카드 밖)
        view.addSubview(headerCard)  // 테이블보다 위 — 스크롤되는 카드를 가린다
        view.addSubview(filterBar)
        view.addSubview(emptyView)
        view.addSubview(addButton)

        tableView.dataSource = self
        tableView.delegate = self
        tableView.layer.cornerRadius = Theme.Radius.lg
        tableView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        tableView.layer.cornerCurve = .continuous
        tableView.clipsToBounds = true
        tableView.translatesAutoresizingMaskIntoConstraints = false
        emptyView.translatesAutoresizingMaskIntoConstraints = false
        filterBar.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            monthNav.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: Theme.Space.lg),
            monthNav.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            monthNav.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            headerCard.topAnchor.constraint(equalTo: monthNav.bottomAnchor, constant: Theme.Space.md),
            headerCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Theme.Space.lg),
            headerCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Theme.Space.lg),

            // 구분선
            insightDivider.heightAnchor.constraint(equalToConstant: 1),
            fixedDivider.heightAnchor.constraint(equalToConstant: 1),

            insightView.heightAnchor.constraint(equalToConstant: 20),
            insightLabel.leadingAnchor.constraint(equalTo: insightView.leadingAnchor),
            insightLabel.trailingAnchor.constraint(equalTo: insightView.trailingAnchor),
            insightLabel.centerYAnchor.constraint(equalTo: insightView.centerYAnchor),

            // 고정지출 행
            fixedRow.heightAnchor.constraint(equalToConstant: 44),
            fixedIcon.leadingAnchor.constraint(equalTo: fixedRow.leadingAnchor),
            fixedIcon.centerYAnchor.constraint(equalTo: fixedRow.centerYAnchor),
            fixedTitleLabel.leadingAnchor.constraint(equalTo: fixedIcon.trailingAnchor, constant: Theme.Space.md),
            fixedTitleLabel.topAnchor.constraint(equalTo: fixedIcon.topAnchor, constant: 1),
            fixedSubLabel.leadingAnchor.constraint(equalTo: fixedTitleLabel.leadingAnchor),
            fixedSubLabel.topAnchor.constraint(equalTo: fixedTitleLabel.bottomAnchor, constant: 1),
            fixedChevron.trailingAnchor.constraint(equalTo: fixedRow.trailingAnchor),
            fixedChevron.centerYAnchor.constraint(equalTo: fixedRow.centerYAnchor),
            fixedActionLabel.trailingAnchor.constraint(equalTo: fixedChevron.leadingAnchor, constant: -Theme.Space.xs),
            fixedActionLabel.centerYAnchor.constraint(equalTo: fixedRow.centerYAnchor),
            fixedAmountLabel.trailingAnchor.constraint(equalTo: fixedActionLabel.leadingAnchor, constant: -Theme.Space.sm),
            fixedAmountLabel.centerYAnchor.constraint(equalTo: fixedRow.centerYAnchor),

            totalLabel.widthAnchor.constraint(lessThanOrEqualTo: headerCard.widthAnchor),

            filterBar.topAnchor.constraint(equalTo: headerCard.bottomAnchor, constant: Theme.Space.md),
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
        monthNav.onPrev     = { [weak self] in self?.shiftMonth(-1) }
        monthNav.onNext     = { [weak self] in self?.shiftMonth(+1) }
        monthNav.onTapMonth = { [weak self] in self?.showMonthPicker() }
        monthNav.onToday    = { [weak self] in self?.jumpToToday() }
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
        presentOnce(nav)
    }

    // MARK: Data
    @objc private func reloadOnChange() { reload(animatedTotal: true) }

    private func reload(animatedTotal: Bool) {
        let allSections = ExpenseStore.shared.daySections(year: year, month: month)
        let total = ExpenseStore.shared.totalAmount(year: year, month: month)
        let insight = ExpenseStore.shared.insight(year: year, month: month)

        monthNav.configure(year: year, month: month)
        totalLabel.setValue(total, animated: animatedTotal)

        // 고정지출 진입 줄
        let fixedTotal = RecurringStore.shared.monthlyTotal()
        fixedAmountLabel.text = fixedTotal.won
        fixedActionLabel.text = RecurringStore.shared.items.isEmpty ? "등록하기" : "관리"

        // 예산 진행바 (P3)
        if let status = ExpenseStore.shared.budgetStatus(year: year, month: month) {
            budgetView.isHidden = false
            budgetView.configure(status, animated: animatedTotal)
            if year == Date().year && month == Date().month {
                NotificationService.evaluateBudget(status)
            }
        } else {
            budgetView.isHidden = true
        }

        configureComparison()

        insightView.isHidden = false
        if insight.entryCount > 0 {
            insightLabel.text = "💡 \(insight.headline) · 하루 평균 \(insight.dailyAverage.won)"
        } else {
            insightLabel.text = "💡 이번 달엔 아직 지출이 없어요"
        }

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
                    || (e.recurringID != nil && "고정지출".contains(q))
                return catOK && textOK
            }
            return items.isEmpty ? nil : DaySection(date: sec.date, expenses: items)
        }
    }

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
    private func shiftMonth(_ delta: Int) {
        Haptic.selection()
        var c = DateComponents(); c.year = year; c.month = month + delta
        if let d = Calendar.current.date(from: c) {
            year = d.year; month = d.month
            reload(animatedTotal: true)
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
        presentOnce(nav)
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
        presentOnce(nav)
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

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat { 26 }
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat { 8 }
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? { UIView() }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        Haptic.light()
        let expense = sections[indexPath.section].expenses[indexPath.row]
        presentEditor(for: expense, successMessage: "수정되었습니다")
    }

    func tableView(_ tableView: UITableView,
                   trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        // 자동 생성분: 오렌지 '건너뛰기' / 일반: 빨강 '삭제' — 캘린더 탭과 동일 동작 (공용 헬퍼)
        let expense = sections[indexPath.section].expenses[indexPath.row]
        return expenseSwipeConfig(expense, in: view)
    }
}
