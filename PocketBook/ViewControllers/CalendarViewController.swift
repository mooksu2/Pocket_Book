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
    private let monthLabel: UILabel = {
        let l = UILabel()
        l.font = Theme.Font.title(16)
        l.textColor = Theme.Color.mainText
        l.textAlignment = .center
        return l
    }()
    private let prevButton = CalendarViewController.navButton("chevron.left")
    private let nextButton = CalendarViewController.navButton("chevron.right")

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
        tv.separatorStyle = .none
        tv.backgroundColor = .clear
        tv.rowHeight = UITableView.automaticDimension
        tv.estimatedRowHeight = 64
        tv.showsVerticalScrollIndicator = false
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
        title = "캘린더"
        buildLayout()
        prevButton.addTarget(self, action: #selector(prevMonth), for: .touchUpInside)
        nextButton.addTarget(self, action: #selector(nextMonth), for: .touchUpInside)
        detailTable.dataSource = self
        detailTable.delegate = self
        NotificationCenter.default.addObserver(self, selector: #selector(reload),
                                               name: .expensesDidChange, object: nil)
        reload()
    }

    // MARK: Layout
    private func buildLayout() {
        let navRow = UIStackView(arrangedSubviews: [prevButton, monthLabel, nextButton])
        navRow.alignment = .center
        navRow.spacing = Theme.Space.sm
        navRow.translatesAutoresizingMaskIntoConstraints = false

        let symbols = ["일", "월", "화", "수", "목", "금", "토"]
        for (i, s) in symbols.enumerated() {
            let l = UILabel()
            l.text = s
            l.font = Theme.Font.caption(12)
            l.textAlignment = .center
            l.textColor = i == 0 ? .systemRed : (i == 6 ? Theme.Color.point : Theme.Color.subText)
            weekdayHeader.addArrangedSubview(l)
        }

        let divider = UIView()
        divider.backgroundColor = Theme.Color.hairline
        divider.translatesAutoresizingMaskIntoConstraints = false

        let detailHeader = UIView()
        detailHeader.translatesAutoresizingMaskIntoConstraints = false
        detailHeader.addSubview(detailDateLabel)
        detailHeader.addSubview(detailTotalLabel)

        [navRow, weekdayHeader, calendarStack, divider, detailHeader, detailTable, emptyLabel].forEach { view.addSubview($0) }

        NSLayoutConstraint.activate([
            navRow.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: Theme.Space.md),
            navRow.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            weekdayHeader.topAnchor.constraint(equalTo: navRow.bottomAnchor, constant: Theme.Space.lg),
            weekdayHeader.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Theme.Space.md),
            weekdayHeader.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Theme.Space.md),

            calendarStack.topAnchor.constraint(equalTo: weekdayHeader.bottomAnchor, constant: Theme.Space.sm),
            calendarStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Theme.Space.md),
            calendarStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Theme.Space.md),

            divider.topAnchor.constraint(equalTo: calendarStack.bottomAnchor, constant: Theme.Space.lg),
            divider.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Theme.Space.lg),
            divider.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Theme.Space.lg),
            divider.heightAnchor.constraint(equalToConstant: 0.5),

            detailHeader.topAnchor.constraint(equalTo: divider.bottomAnchor, constant: Theme.Space.md),
            detailHeader.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Theme.Space.lg),
            detailHeader.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Theme.Space.lg),
            detailHeader.heightAnchor.constraint(equalToConstant: 24),

            detailDateLabel.leadingAnchor.constraint(equalTo: detailHeader.leadingAnchor),
            detailDateLabel.centerYAnchor.constraint(equalTo: detailHeader.centerYAnchor),
            detailTotalLabel.trailingAnchor.constraint(equalTo: detailHeader.trailingAnchor),
            detailTotalLabel.centerYAnchor.constraint(equalTo: detailHeader.centerYAnchor),

            detailTable.topAnchor.constraint(equalTo: detailHeader.bottomAnchor, constant: Theme.Space.xs),
            detailTable.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            detailTable.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            detailTable.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyLabel.topAnchor.constraint(equalTo: detailTable.topAnchor, constant: Theme.Space.xl),
            emptyLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            emptyLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    // MARK: Data
    @objc private func reload() {
        let cal = Calendar.current
        monthLabel.text = "\(year)년 \(month)월"
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
    }

    // MARK: Month nav
    @objc private func prevMonth() { shift(-1) }
    @objc private func nextMonth() { shift(+1) }
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
