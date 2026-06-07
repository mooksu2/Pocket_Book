// ViewControllers/StatsViewController.swift
import UIKit

final class StatsViewController: UIViewController {

    private var year = Date().year
    private var month = Date().month

    // MARK: Header
    private let monthLabel: UILabel = {
        let l = UILabel()
        l.font = Theme.Font.title(16)
        l.textColor = Theme.Color.mainText
        l.textAlignment = .center
        return l
    }()
    private let prevButton = StatsViewController.navButton("chevron.left")
    private let nextButton = StatsViewController.navButton("chevron.right")

    private let modeControl: UISegmentedControl = {
        let sc = UISegmentedControl(items: ["도넛", "막대"])
        sc.selectedSegmentIndex = 0
        sc.selectedSegmentTintColor = Theme.Color.point
        sc.setTitleTextAttributes([.foregroundColor: UIColor.white,
                                   .font: Theme.Font.title(13)], for: .selected)
        sc.setTitleTextAttributes([.foregroundColor: Theme.Color.subText,
                                   .font: Theme.Font.body(13)], for: .normal)
        sc.translatesAutoresizingMaskIntoConstraints = false
        return sc
    }()

    private let donut = DonutChartView()
    private let bars = BarChartView()
    private var expandedCategory: Category?
    private var lastTotals: [Category: Int] = [:]
    private var lastTotal = 0
    private let breakdownStack: UIStackView = {
        let s = UIStackView()
        s.axis = .vertical
        s.spacing = Theme.Space.xs
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()
    private lazy var emptyView = EmptyStateView(
        symbol: "chart.pie", title: "표시할 데이터가 없어요",
        subtitle: "이번 달 지출을 기록하면\n여기에서 분석을 볼 수 있어요")

    private func rebuildBreakdown() {
        breakdownStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let sorted = Category.allCases
            .map { ($0, lastTotals[$0] ?? 0) }
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
        for (cat, amount) in sorted {
            let frac = lastTotal > 0 ? CGFloat(amount) / CGFloat(lastTotal) : 0
            let row = CategoryBreakdownRow(category: cat, amount: amount, fraction: frac)
            row.setExpanded(expandedCategory == cat)
            row.onTap = { [weak self] in
                guard let self = self else { return }
                self.expandedCategory = (self.expandedCategory == cat) ? nil : cat
                self.rebuildBreakdown()
            }
            breakdownStack.addArrangedSubview(row)

            if expandedCategory == cat {
                let tags = ExpenseStore.shared.tagTotals(year: year, month: month, category: cat)
                for t in tags {
                    let f = amount > 0 ? CGFloat(t.amount) / CGFloat(amount) : 0
                    breakdownStack.addArrangedSubview(makeTagRow(tag: t.tag, amount: t.amount, fraction: f, color: cat.color))
                }
            }
        }
    }

    private func makeTagRow(tag: String, amount: Int, fraction: CGFloat, color: UIColor) -> UIView {
        let row = UIView()
        row.translatesAutoresizingMaskIntoConstraints = false

        let bullet = UIView()
        bullet.backgroundColor = color.withAlphaComponent(0.55)
        bullet.layer.cornerRadius = 2.5
        bullet.translatesAutoresizingMaskIntoConstraints = false

        let name = UILabel()
        name.text = tag
        name.font = Theme.Font.body(13)
        name.textColor = Theme.Color.subText
        name.translatesAutoresizingMaskIntoConstraints = false

        let pct = UILabel()
        pct.text = "\(Int(fraction * 100))%"
        pct.font = Theme.Font.caption(11)
        pct.textColor = Theme.Color.tertiaryText
        pct.translatesAutoresizingMaskIntoConstraints = false

        let amt = UILabel()
        amt.text = amount.won
        amt.font = Theme.Font.money(13, .medium)
        amt.textColor = Theme.Color.subText
        amt.textAlignment = .right
        amt.translatesAutoresizingMaskIntoConstraints = false

        [bullet, name, pct, amt].forEach { row.addSubview($0) }
        NSLayoutConstraint.activate([
            bullet.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 18),
            bullet.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            bullet.widthAnchor.constraint(equalToConstant: 5),
            bullet.heightAnchor.constraint(equalToConstant: 5),

            name.leadingAnchor.constraint(equalTo: bullet.trailingAnchor, constant: 8),
            name.centerYAnchor.constraint(equalTo: row.centerYAnchor),

            pct.leadingAnchor.constraint(equalTo: name.trailingAnchor, constant: 6),
            pct.centerYAnchor.constraint(equalTo: row.centerYAnchor),

            amt.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            amt.centerYAnchor.constraint(equalTo: row.centerYAnchor),

            row.heightAnchor.constraint(equalToConstant: 30),
        ])
        return row
    }

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
        prevButton.addTarget(self, action: #selector(prevMonth), for: .touchUpInside)
        nextButton.addTarget(self, action: #selector(nextMonth), for: .touchUpInside)
        modeControl.addTarget(self, action: #selector(modeChanged), for: .valueChanged)
        NotificationCenter.default.addObserver(self, selector: #selector(reload),
                                               name: .expensesDidChange, object: nil)
        reload()
    }

    private func buildLayout() {
        donut.translatesAutoresizingMaskIntoConstraints = false
        bars.translatesAutoresizingMaskIntoConstraints = false
        emptyView.translatesAutoresizingMaskIntoConstraints = false

        let navRow = UIStackView(arrangedSubviews: [prevButton, monthLabel, nextButton])
        navRow.alignment = .center
        navRow.spacing = Theme.Space.sm
        navRow.translatesAutoresizingMaskIntoConstraints = false

        let chartContainer = UIView()
        chartContainer.translatesAutoresizingMaskIntoConstraints = false
        chartContainer.addSubview(donut)
        chartContainer.addSubview(bars)

        let breakdownTitle = UILabel()
        breakdownTitle.text = "카테고리별 내역"
        breakdownTitle.font = Theme.Font.caption(13)
        breakdownTitle.textColor = Theme.Color.subText
        breakdownTitle.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(navRow)
        view.addSubview(modeControl)
        view.addSubview(chartContainer)
        view.addSubview(breakdownTitle)
        view.addSubview(breakdownStack)
        view.addSubview(emptyView)

        NSLayoutConstraint.activate([
            navRow.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: Theme.Space.md),
            navRow.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            modeControl.topAnchor.constraint(equalTo: navRow.bottomAnchor, constant: Theme.Space.lg),
            modeControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Theme.Space.xl),
            modeControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Theme.Space.xl),
            modeControl.heightAnchor.constraint(equalToConstant: 36),

            chartContainer.topAnchor.constraint(equalTo: modeControl.bottomAnchor, constant: Theme.Space.lg),
            chartContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Theme.Space.xl),
            chartContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Theme.Space.xl),
            chartContainer.heightAnchor.constraint(equalToConstant: 230),

            donut.centerXAnchor.constraint(equalTo: chartContainer.centerXAnchor),
            donut.centerYAnchor.constraint(equalTo: chartContainer.centerYAnchor),
            donut.widthAnchor.constraint(equalToConstant: 210),
            donut.heightAnchor.constraint(equalToConstant: 210),

            bars.topAnchor.constraint(equalTo: chartContainer.topAnchor),
            bars.leadingAnchor.constraint(equalTo: chartContainer.leadingAnchor),
            bars.trailingAnchor.constraint(equalTo: chartContainer.trailingAnchor),
            bars.bottomAnchor.constraint(equalTo: chartContainer.bottomAnchor),

            breakdownTitle.topAnchor.constraint(equalTo: chartContainer.bottomAnchor, constant: Theme.Space.xl),
            breakdownTitle.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Theme.Space.xl),

            breakdownStack.topAnchor.constraint(equalTo: breakdownTitle.bottomAnchor, constant: Theme.Space.sm),
            breakdownStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Theme.Space.xl),
            breakdownStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Theme.Space.xl),

            emptyView.topAnchor.constraint(equalTo: modeControl.bottomAnchor),
            emptyView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            emptyView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            emptyView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    // MARK: Data
    @objc private func reload() {
        let totals = ExpenseStore.shared.totals(year: year, month: month)
        let total = ExpenseStore.shared.totalAmount(year: year, month: month)
        monthLabel.text = "\(year)년 \(month)월"

        let hasData = total > 0
        emptyView.isHidden = hasData
        donut.isHidden = !hasData || modeControl.selectedSegmentIndex != 0
        bars.isHidden  = !hasData || modeControl.selectedSegmentIndex != 1
        modeControl.isHidden = !hasData
        breakdownStack.isHidden = !hasData

        guard hasData else { return }
        donut.setData(totals: totals, total: total)
        bars.setData(totals: totals, total: total)

        // breakdown 갱신
        lastTotals = totals
        lastTotal = total
        rebuildBreakdown()
    }

    @objc private func modeChanged() {
        Haptic.selection()
        let donutMode = modeControl.selectedSegmentIndex == 0
        UIView.transition(with: view, duration: 0.25, options: .transitionCrossDissolve) {
            self.donut.isHidden = !donutMode
            self.bars.isHidden = donutMode
        }
        reload()
    }

    @objc private func prevMonth() { shift(-1) }
    @objc private func nextMonth() { shift(+1) }
    private func shift(_ d: Int) {
        Haptic.selection()
        var c = DateComponents(); c.year = year; c.month = month + d
        if let date = Calendar.current.date(from: c) {
            year = date.year; month = date.month; reload()
        }
    }
}
