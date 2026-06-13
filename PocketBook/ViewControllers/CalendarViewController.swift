// ViewControllers/CalendarViewController.swift
import UIKit

/// 달력으로 지출 내역 보기. 지출 있는 날은 점으로 표시, 날짜 탭 시 그 날 내역을 아래에 표시.
final class CalendarViewController: UIViewController {

    private var year = Date().year
    private var month = Date().month
    private var selectedDay = Calendar.current.component(.day, from: Date())

    private var dailyTotals: [Int: Int] = [:]
    private var dailyTops: [Int: Category] = [:]
    private var leadingBlanks = 0
    private var daysInMonth = 30
    private var dayToCell: [Int: CalendarDayCell] = [:]
    private var dayExpenses: [Expense] = []

    // MARK: Header
    private let monthButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.baseForegroundColor = Theme.Color.mainText
        config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer {
            var a = $0; a.font = Theme.Font.title(16); return a
        }
        // 탭 가능함을 알리는 아래 화살표 + 살짝 눌리는 피드백
        config.image = UIImage(systemName: "chevron.down",
                               withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .bold))
        config.imagePlacement = .trailing
        config.imagePadding = 5
        let b = UIButton(configuration: config)
        b.configurationUpdateHandler = { btn in
            btn.alpha = btn.isHighlighted ? 0.5 : 1
        }
        return b
    }()
    private let prevButton = CalendarViewController.navButton("chevron.left")
    private let nextButton = CalendarViewController.navButton("chevron.right")
    private let todayButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.title = "오늘"
        config.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 10, bottom: 5, trailing: 10)
        config.baseForegroundColor = Theme.Color.point
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer {
            var a = $0; a.font = Theme.Font.caption(12); return a
        }
        let b = UIButton(configuration: config)
        b.backgroundColor = Theme.Color.pointSoft
        b.layer.cornerRadius = 12
        b.layer.cornerCurve = .continuous
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    private let weekdayHeader: UIStackView = {
        let s = UIStackView()
        s.axis = .horizontal
        s.distribution = .fillEqually
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()
    private let calendarStack: UIStackView = {
        let s = UIStackView()
        s.axis = .vertical
        s.spacing = 2
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    // MARK: Detail
    private let detailDateLabel: UILabel = {
        let l = UILabel()
        l.font = Theme.Font.title(15)
        l.textColor = Theme.Color.mainText
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    private let detailTotalLabel: UILabel = {
        let l = UILabel()
        l.font = Theme.Font.money(15, .bold)
        l.textColor = Theme.Color.point
        l.textAlignment = .right
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    private let detailTable: UITableView = {
        let tv = UITableView(frame: .zero, style: .plain)
        tv.register(ExpenseCell.self, forCellReuseIdentifier: ExpenseCell.reuseID)
        tv.separatorStyle = .singleLine
        tv.separatorColor = Theme.Color.hairline
        tv.separatorInset = UIEdgeInsets(top: 0, left: 64, bottom: 0, right: 16)
        tv.backgroundColor = .clear
        tv.rowHeight = UITableView.automaticDimension
        tv.estimatedRowHeight = 64
        tv.showsVerticalScrollIndicator = false
        tv.layer.cornerRadius = Theme.Radius.lg   // 카드 하단 모서리 밖으로 셀이 돌출되지 않게
        tv.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]  // 아래 두 모서리만
        tv.clipsToBounds = true
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()
    private let emptyLabel: UILabel = {
        let l = UILabel()
        l.text = "이 날은 지출이 없어요"
        l.font = Theme.Font.body(14)
        l.textColor = Theme.Color.tertiaryText
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private static func navButton(_ symbol: String) -> UIButton {
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: symbol,
                               withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold))
        config.baseForegroundColor = Theme.Color.point
        // 터치 영역 확대 — 화살표 판정이 빡빡하지 않게
        config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12)
        let b = UIButton(configuration: config)
        return b
    }

    // MARK: Lifecycle
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 타이틀이 없으므로 네비바를 숨겨 콘텐츠를 위로 끌어올린다
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.Color.background
        title = ""   // 콘텐츠로 식별 가능 → 공간 확보
        buildLayout()
        prevButton.addTarget(self, action: #selector(prevMonth), for: .touchUpInside)
        nextButton.addTarget(self, action: #selector(nextMonth), for: .touchUpInside)
        todayButton.addTarget(self, action: #selector(jumpToToday), for: .touchUpInside)
        detailTable.dataSource = self
        detailTable.delegate = self
        NotificationCenter.default.addObserver(self, selector: #selector(reload),
                                               name: .expensesDidChange, object: nil)
        reload()
    }

    // MARK: 카드 컨테이너
    private let calendarCard: UIView = {
        let v = UIView()
        v.backgroundColor = Theme.Color.card
        v.layer.cornerRadius = Theme.Radius.lg
        v.layer.cornerCurve = .continuous
        v.translatesAutoresizingMaskIntoConstraints = false
        Theme.applyCardShadow(to: v.layer, opacity: 0.05, radius: 16, y: 4)
        return v
    }()
    private let detailCard: UIView = {
        let v = UIView()
        v.backgroundColor = Theme.Color.card
        v.layer.cornerRadius = Theme.Radius.lg
        v.layer.cornerCurve = .continuous
        v.translatesAutoresizingMaskIntoConstraints = false
        Theme.applyCardShadow(to: v.layer, opacity: 0.05, radius: 16, y: 4)
        return v
    }()
    /// 상세 테이블 높이 — 내용(contentSize)에 맞춰 갱신, 화면 넘으면 스크롤
    private var detailTableHeight: NSLayoutConstraint!

    // MARK: Layout
    private func buildLayout() {
        // 월 내비: 월 그룹은 정중앙, 오늘 버튼은 우측 (기록 탭과 동일)
        let monthGroup = UIStackView(arrangedSubviews: [prevButton, monthButton, nextButton])
        monthGroup.alignment = .center
        monthGroup.spacing = Theme.Space.sm
        monthGroup.translatesAutoresizingMaskIntoConstraints = false

        let navRow = UIView()
        navRow.translatesAutoresizingMaskIntoConstraints = false
        navRow.addSubview(monthGroup)
        navRow.addSubview(todayButton)
        NSLayoutConstraint.activate([
            monthGroup.centerXAnchor.constraint(equalTo: navRow.centerXAnchor),
            monthGroup.topAnchor.constraint(equalTo: navRow.topAnchor),
            monthGroup.bottomAnchor.constraint(equalTo: navRow.bottomAnchor),
            todayButton.trailingAnchor.constraint(equalTo: navRow.trailingAnchor, constant: -Theme.Space.lg),
            todayButton.centerYAnchor.constraint(equalTo: navRow.centerYAnchor),
        ])

        // 월 라벨 탭 → 월 피커
        monthButton.addTarget(self, action: #selector(showMonthPicker), for: .touchUpInside)

        let symbols = ["일", "월", "화", "수", "목", "금", "토"]
        for (i, s) in symbols.enumerated() {
            let l = UILabel()
            l.text = s
            l.font = Theme.Font.caption(12)
            l.textAlignment = .center
            l.textColor = i == 0 ? .systemRed : (i == 6 ? Theme.Color.point : Theme.Color.subText)
            weekdayHeader.addArrangedSubview(l)
        }

        let detailHeader = UIView()
        detailHeader.translatesAutoresizingMaskIntoConstraints = false
        detailHeader.addSubview(detailDateLabel)
        detailHeader.addSubview(detailTotalLabel)

        // navRow는 카드 밖, 달력은 calendarCard 안, 상세는 detailCard 안
        view.addSubview(navRow)
        view.addSubview(calendarCard)
        view.addSubview(detailCard)
        calendarCard.addSubview(weekdayHeader)
        calendarCard.addSubview(calendarStack)
        detailCard.addSubview(detailHeader)
        detailCard.addSubview(detailTable)
        detailCard.addSubview(emptyLabel)

        NSLayoutConstraint.activate([
            navRow.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: Theme.Space.lg),
            navRow.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navRow.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            // 달력 카드
            calendarCard.topAnchor.constraint(equalTo: navRow.bottomAnchor, constant: Theme.Space.md),
            calendarCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Theme.Space.lg),
            calendarCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Theme.Space.lg),

            weekdayHeader.topAnchor.constraint(equalTo: calendarCard.topAnchor, constant: Theme.Space.lg),
            weekdayHeader.leadingAnchor.constraint(equalTo: calendarCard.leadingAnchor, constant: Theme.Space.md),
            weekdayHeader.trailingAnchor.constraint(equalTo: calendarCard.trailingAnchor, constant: -Theme.Space.md),

            calendarStack.topAnchor.constraint(equalTo: weekdayHeader.bottomAnchor, constant: Theme.Space.sm),
            calendarStack.leadingAnchor.constraint(equalTo: calendarCard.leadingAnchor, constant: Theme.Space.md),
            calendarStack.trailingAnchor.constraint(equalTo: calendarCard.trailingAnchor, constant: -Theme.Space.md),
            calendarStack.bottomAnchor.constraint(equalTo: calendarCard.bottomAnchor, constant: -Theme.Space.lg),

            // 상세 카드 — 높이는 내용(테이블)에 맞춤. 화면을 넘으면 카드 안에서 스크롤
            detailCard.topAnchor.constraint(equalTo: calendarCard.bottomAnchor, constant: Theme.Space.md),
            detailCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Theme.Space.lg),
            detailCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Theme.Space.lg),
            detailCard.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -Theme.Space.md),

            detailHeader.topAnchor.constraint(equalTo: detailCard.topAnchor, constant: Theme.Space.lg),
            detailHeader.leadingAnchor.constraint(equalTo: detailCard.leadingAnchor, constant: Theme.Space.lg),
            detailHeader.trailingAnchor.constraint(equalTo: detailCard.trailingAnchor, constant: -Theme.Space.lg),
            detailHeader.heightAnchor.constraint(equalToConstant: 24),

            detailDateLabel.leadingAnchor.constraint(equalTo: detailHeader.leadingAnchor),
            detailDateLabel.centerYAnchor.constraint(equalTo: detailHeader.centerYAnchor),
            detailTotalLabel.trailingAnchor.constraint(equalTo: detailHeader.trailingAnchor),
            detailTotalLabel.centerYAnchor.constraint(equalTo: detailHeader.centerYAnchor),

            detailTable.topAnchor.constraint(equalTo: detailHeader.bottomAnchor, constant: Theme.Space.sm),
            detailTable.leadingAnchor.constraint(equalTo: detailCard.leadingAnchor),
            detailTable.trailingAnchor.constraint(equalTo: detailCard.trailingAnchor),
            detailTable.bottomAnchor.constraint(equalTo: detailCard.bottomAnchor),

            emptyLabel.centerYAnchor.constraint(equalTo: detailTable.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(equalTo: detailCard.leadingAnchor),
            emptyLabel.trailingAnchor.constraint(equalTo: detailCard.trailingAnchor),
        ])

        // 테이블 높이를 내용에 맞춤 (화면 절반을 넘으면 그 선에서 멈추고 스크롤)
        detailTableHeight = detailTable.heightAnchor.constraint(equalToConstant: 200)
        detailTableHeight.priority = .defaultHigh   // 카드 하단 lessThanOrEqual과 충돌 시 양보
        detailTableHeight.isActive = true
    }

    /// 테이블 내용 높이를 카드에 반영 (스크롤 없이 딱 맞게, 넘치면 최대치에서 스크롤)
    private func updateDetailTableHeight() {
        view.layoutIfNeeded()
        let contentH = detailTable.contentSize.height
        // safeArea 하단(탭바는 additionalSafeAreaInsets로 이미 반영됨)까지를 최대로
        let safeBottom = view.safeAreaLayoutGuide.layoutFrame.maxY - Theme.Space.md
        let tableTop = detailTable.convert(CGPoint.zero, to: view).y
        let maxH = max(safeBottom - tableTop - Theme.Space.sm, 120)
        // 지출이 없는 날: emptyLabel이 들어갈 최소 높이를 줘서 카드 위아래 여백을 맞춘다
        let minH: CGFloat = dayExpenses.isEmpty ? 56 : 1
        let newH = min(max(contentH, minH), maxH)
        if abs(detailTableHeight.constant - newH) > 0.5 {   // 변화 있을 때만 → 루프 방지
            detailTableHeight.constant = newH
        }
        detailTable.isScrollEnabled = contentH > maxH
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateDetailTableHeight()   // 회전·초기 레이아웃 후 높이 재보정
    }

    // MARK: Data
    @objc private func reload() {
        let cal = Calendar.current
        monthButton.configuration?.title = "\(year)년 \(month)월"
        todayButton.isHidden = (year == Date().year && month == Date().month)
        dailyTotals = ExpenseStore.shared.dailyTotals(year: year, month: month)
        dailyTops = ExpenseStore.shared.dailyTopCategory(year: year, month: month)

        var comps = DateComponents(); comps.year = year; comps.month = month; comps.day = 1
        let first = cal.date(from: comps) ?? Date()
        leadingBlanks = cal.component(.weekday, from: first) - 1
        daysInMonth = cal.range(of: .day, in: .month, for: first)?.count ?? 30
        if selectedDay > daysInMonth { selectedDay = daysInMonth }

        buildGrid()
        updateDetail()
    }

    private func buildGrid() {
        calendarStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        dayToCell.removeAll()

        let totalCells = leadingBlanks + daysInMonth
        let rows = Int(ceil(Double(totalCells) / 7.0))

        for row in 0..<rows {
            let rowStack = UIStackView()
            rowStack.axis = .horizontal
            rowStack.distribution = .fillEqually
            rowStack.translatesAutoresizingMaskIntoConstraints = false
            rowStack.heightAnchor.constraint(equalToConstant: 46).isActive = true

            for col in 0..<7 {
                let index = row * 7 + col
                let cell = CalendarDayCell()
                if index < leadingBlanks || index >= leadingBlanks + daysInMonth {
                    cell.configure(date: nil, day: nil, column: col,
                                   total: nil,
                                   isToday: false, isSelected: false)
                } else {
                    let day = index - leadingBlanks + 1
                    cell.tag = day
                    cell.addTarget(self, action: #selector(dayTapped(_:)), for: .touchUpInside)
                    dayToCell[day] = cell
                    style(cell, day: day, column: col)
                }
                rowStack.addArrangedSubview(cell)
            }
            calendarStack.addArrangedSubview(rowStack)
        }
    }

    private func style(_ cell: CalendarDayCell, day: Int, column: Int) {
        cell.configure(date: dateFor(day), day: day, column: column,
                       total: dailyTotals[day],
                       isToday: isToday(day),
                       isSelected: day == selectedDay)
    }

    private func column(for day: Int) -> Int { (leadingBlanks + day - 1) % 7 }
    private func isToday(_ day: Int) -> Bool {
        let t = Date()
        return year == t.year && month == t.month && day == Calendar.current.component(.day, from: t)
    }
    private func dateFor(_ day: Int) -> Date {
        var c = DateComponents(); c.year = year; c.month = month; c.day = day
        return Calendar.current.date(from: c) ?? Date()
    }

    @objc private func dayTapped(_ sender: CalendarDayCell) {
        let newDay = sender.tag
        guard newDay != selectedDay else { return }
        Haptic.selection()
        let old = selectedDay
        selectedDay = newDay
        if let oldCell = dayToCell[old] { style(oldCell, day: old, column: column(for: old)) }
        style(sender, day: newDay, column: column(for: newDay))
        updateDetail()
    }

    private func updateDetail() {
        let date = dateFor(selectedDay)
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일 (E)"
        detailDateLabel.text = f.string(from: date)

        dayExpenses = ExpenseStore.shared.expenses(on: date)
        let total = dayExpenses.reduce(0) { $0 + $1.amount }
        detailTotalLabel.text = dayExpenses.isEmpty ? "" : total.won
        emptyLabel.isHidden = !dayExpenses.isEmpty
        detailTable.reloadData()
        detailTable.performBatchUpdates(nil) { [weak self] _ in
            self?.updateDetailTableHeight()
        }
        // 가벼운 페이드 + 다운-업 전환 (데이터가 툭 끊기지 않고 유기적으로 바뀌게)
        for v in [detailTable, emptyLabel] as [UIView] {
            v.alpha = 0
            v.transform = CGAffineTransform(translationX: 0, y: 8)
        }
        UIView.animate(withDuration: 0.18, delay: 0, options: [.curveEaseOut]) {
            self.detailTable.alpha = 1; self.detailTable.transform = .identity
            self.emptyLabel.alpha = 1; self.emptyLabel.transform = .identity
        }
    }

    // MARK: Month nav
    @objc private func prevMonth() { shift(-1) }
    @objc private func nextMonth() { shift(+1) }

    @objc private func jumpToToday() {
        Haptic.selection()
        let t = Date()
        year = t.year; month = t.month
        selectedDay = Calendar.current.component(.day, from: t)
        reload()
    }

    @objc private func showMonthPicker() {
        Haptic.selection()
        let vc = MonthPickerViewController(year: year, month: month)
        vc.onSelect = { [weak self] y, m in
            guard let self = self else { return }
            self.year = y; self.month = m
            let t = Date()
            self.selectedDay = (y == t.year && m == t.month) ? Calendar.current.component(.day, from: t) : 1
            self.reload()
        }
        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .pageSheet
        present(nav, animated: true)
    }
    private func shift(_ delta: Int) {
        Haptic.selection()
        var c = DateComponents(); c.year = year; c.month = month + delta
        guard let d = Calendar.current.date(from: c) else { return }
        year = d.year; month = d.month
        // 이동한 달이 현재 달이면 오늘, 아니면 1일 선택
        let t = Date()
        selectedDay = (year == t.year && month == t.month) ? Calendar.current.component(.day, from: t) : 1
        reload()

        calendarStack.alpha = 0.4
        calendarStack.transform = CGAffineTransform(translationX: delta > 0 ? 16 : -16, y: 0)
        UIView.animate(withDuration: 0.22) {
            self.calendarStack.alpha = 1
            self.calendarStack.transform = .identity
        }
    }

    private func presentEditor(for expense: Expense) {
        let vc = AddViewController(editing: expense)
        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .pageSheet
        present(nav, animated: true)
    }
}

// MARK: - Detail table
extension CalendarViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { dayExpenses.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ExpenseCell.reuseID, for: indexPath) as! ExpenseCell
        cell.configure(with: dayExpenses[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        Haptic.light()
        presentEditor(for: dayExpenses[indexPath.row])
    }

    func tableView(_ tableView: UITableView,
                   trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        let expense = dayExpenses[indexPath.row]
        let delete = UIContextualAction(style: .destructive, title: nil) { _, _, done in
            Haptic.warning()
            ExpenseStore.shared.delete(id: expense.id)
            done(true)
        }
        delete.image = UIImage(systemName: "trash.fill")
        delete.backgroundColor = .systemRed
        return UISwipeActionsConfiguration(actions: [delete])
    }
}
