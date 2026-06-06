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
        breakdownStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let sorted = Category.allCases
            .map { ($0, totals[$0] ?? 0) }
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
        for (cat, amount) in sorted {
            let frac = CGFloat(amount) / CGFloat(total)
            breakdownStack.addArrangedSubview(CategoryBreakdownRow(category: cat, amount: amount, fraction: frac))
        }
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
