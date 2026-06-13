// ViewControllers/StatsViewController.swift
import UIKit

final class StatsViewController: UIViewController {

    private var year = Date().year
    private var month = Date().month

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
    private let prevButton = StatsViewController.navButton("chevron.left")
    private let nextButton = StatsViewController.navButton("chevron.right")
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
    private var expandedCategories: Set<Category> = []   // 여러 카테고리 동시 펼침
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

    /// 고정지출(매달 동일한 지출)을 빼고 변동지출만 분석
    private var excludeFixed = false
    private lazy var fixedFilterButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.title = "고정지출 제외"
        config.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 12, bottom: 5, trailing: 12)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer {
            var a = $0; a.font = Theme.Font.caption(12); return a
        }
        let b = UIButton(configuration: config)
        b.layer.cornerRadius = 14
        b.layer.cornerCurve = .continuous
        b.translatesAutoresizingMaskIntoConstraints = false
        b.addTarget(self, action: #selector(toggleFixedFilter), for: .touchUpInside)
        return b
    }()

    private func rebuildBreakdown() {
        breakdownStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let sorted = Category.allCases
            .map { ($0, lastTotals[$0] ?? 0) }
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
        for (cat, amount) in sorted {
            let frac = lastTotal > 0 ? CGFloat(amount) / CGFloat(lastTotal) : 0
            let row = CategoryBreakdownRow(category: cat, amount: amount, fraction: frac)
            row.setExpanded(expandedCategories.contains(cat))
            row.onTap = { [weak self] in
                guard let self = self else { return }
                if self.expandedCategories.contains(cat) {
                    self.expandedCategories.remove(cat)
                } else {
                    self.expandedCategories.insert(cat)
                }
                self.rebuildBreakdown()
            }
            breakdownStack.addArrangedSubview(row)

            if expandedCategories.contains(cat) {
                let tags = ExpenseStore.shared.tagTotals(year: year, month: month, category: cat, excludingFixed: excludeFixed)
                for t in tags {
                    let f = amount > 0 ? CGFloat(t.amount) / CGFloat(amount) : 0
                    breakdownStack.addArrangedSubview(makeTagRow(tag: t.tag, amount: t.amount, fraction: f, color: cat.color))
                }
            }
        }
        // 행 추가/제거 후 스크롤뷰가 contentSize를 다시 계산하도록
        view.layoutIfNeeded()
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
        buildLayout()
        title = ""   // 콘텐츠로 식별 가능 → 공간 확보
        prevButton.addTarget(self, action: #selector(prevMonth), for: .touchUpInside)
        nextButton.addTarget(self, action: #selector(nextMonth), for: .touchUpInside)
        todayButton.addTarget(self, action: #selector(jumpToToday), for: .touchUpInside)
        modeControl.addTarget(self, action: #selector(modeChanged), for: .valueChanged)
        NotificationCenter.default.addObserver(self, selector: #selector(reload),
                                               name: .expensesDidChange, object: nil)
        reload()
    }

    // MARK: 카드 컨테이너
    private let scrollView: UIScrollView = {
        let s = UIScrollView()
        s.showsVerticalScrollIndicator = false
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()
    private let chartCard: UIView = {
        let v = UIView()
        v.backgroundColor = Theme.Color.card
        v.layer.cornerRadius = Theme.Radius.lg
        v.layer.cornerCurve = .continuous
        v.translatesAutoresizingMaskIntoConstraints = false
        Theme.applyCardShadow(to: v.layer, opacity: 0.05, radius: 16, y: 4)
        return v
    }()
    private let breakdownCard: UIView = {
        let v = UIView()
        v.backgroundColor = Theme.Color.card
        v.layer.cornerRadius = Theme.Radius.lg
        v.layer.cornerCurve = .continuous
        v.translatesAutoresizingMaskIntoConstraints = false
        Theme.applyCardShadow(to: v.layer, opacity: 0.05, radius: 16, y: 4)
        return v
    }()

    /// 고정지출 제외 토글로 인해 표시할 게 없을 때 차트 자리에 띄우는 안내
    private let filteredEmptyLabel: UILabel = {
        let l = UILabel()
        l.text = "고정지출을 제외한 지출이 없어요"
        l.font = Theme.Font.body(14)
        l.textColor = Theme.Color.tertiaryText
        l.textAlignment = .center
        l.numberOfLines = 0
        l.isHidden = true
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    /// 도넛 모드 색-카테고리 범례 (막대엔 자체 라벨이 있어 불필요)
    private let legendStack: UIStackView = {
        let s = UIStackView()
        s.axis = .horizontal
        s.spacing = 14
        s.alignment = .center
        s.distribution = .equalSpacing
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    private func buildLayout() {
        donut.translatesAutoresizingMaskIntoConstraints = false
        bars.translatesAutoresizingMaskIntoConstraints = false
        emptyView.translatesAutoresizingMaskIntoConstraints = false

        // 월 내비: 월 그룹 정중앙 + 오늘 버튼 우측 (기록 탭과 동일)
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

        monthButton.addTarget(self, action: #selector(showMonthPicker), for: .touchUpInside)

        let chartContainer = UIView()
        chartContainer.translatesAutoresizingMaskIntoConstraints = false
        chartContainer.addSubview(donut)
        chartContainer.addSubview(bars)
        chartContainer.addSubview(filteredEmptyLabel)
        chartContainer.addSubview(legendStack)

        let breakdownTitle = UILabel()
        breakdownTitle.text = "카테고리별 내역"
        breakdownTitle.font = Theme.Font.caption(13)
        breakdownTitle.textColor = Theme.Color.subText
        breakdownTitle.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(navRow)
        view.addSubview(scrollView)
        view.addSubview(emptyView)
        scrollView.addSubview(chartCard)
        scrollView.addSubview(breakdownCard)
        chartCard.addSubview(modeControl)
        chartCard.addSubview(fixedFilterButton)
        chartCard.addSubview(chartContainer)
        breakdownCard.addSubview(breakdownTitle)
        breakdownCard.addSubview(breakdownStack)

        let cg = scrollView.contentLayoutGuide
        let fg = scrollView.frameLayoutGuide

        NSLayoutConstraint.activate([
            navRow.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: Theme.Space.lg),
            navRow.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navRow.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            scrollView.topAnchor.constraint(equalTo: navRow.bottomAnchor, constant: Theme.Space.md),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            // 차트 카드
            chartCard.topAnchor.constraint(equalTo: cg.topAnchor),
            chartCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Theme.Space.lg),
            chartCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Theme.Space.lg),
            chartCard.widthAnchor.constraint(equalTo: fg.widthAnchor, constant: -2 * Theme.Space.lg),

            modeControl.topAnchor.constraint(equalTo: chartCard.topAnchor, constant: Theme.Space.lg),
            modeControl.leadingAnchor.constraint(equalTo: chartCard.leadingAnchor, constant: Theme.Space.lg),
            modeControl.trailingAnchor.constraint(equalTo: chartCard.trailingAnchor, constant: -Theme.Space.lg),
            modeControl.heightAnchor.constraint(equalToConstant: 36),

            fixedFilterButton.topAnchor.constraint(equalTo: modeControl.bottomAnchor, constant: Theme.Space.md),
            fixedFilterButton.trailingAnchor.constraint(equalTo: chartCard.trailingAnchor, constant: -Theme.Space.lg),

            chartContainer.topAnchor.constraint(equalTo: fixedFilterButton.bottomAnchor, constant: Theme.Space.sm),
            chartContainer.leadingAnchor.constraint(equalTo: chartCard.leadingAnchor, constant: Theme.Space.md),
            chartContainer.trailingAnchor.constraint(equalTo: chartCard.trailingAnchor, constant: -Theme.Space.md),
            chartContainer.heightAnchor.constraint(equalToConstant: 230),
            chartContainer.bottomAnchor.constraint(equalTo: chartCard.bottomAnchor, constant: -Theme.Space.lg),

            donut.centerXAnchor.constraint(equalTo: chartContainer.centerXAnchor),
            donut.centerYAnchor.constraint(equalTo: chartContainer.centerYAnchor, constant: -14),
            donut.widthAnchor.constraint(equalToConstant: 200),
            donut.heightAnchor.constraint(equalToConstant: 200),

            legendStack.centerXAnchor.constraint(equalTo: chartContainer.centerXAnchor),
            legendStack.bottomAnchor.constraint(equalTo: chartContainer.bottomAnchor),
            legendStack.leadingAnchor.constraint(greaterThanOrEqualTo: chartContainer.leadingAnchor),
            legendStack.trailingAnchor.constraint(lessThanOrEqualTo: chartContainer.trailingAnchor),

            bars.topAnchor.constraint(equalTo: chartContainer.topAnchor),
            bars.leadingAnchor.constraint(equalTo: chartContainer.leadingAnchor),
            bars.trailingAnchor.constraint(equalTo: chartContainer.trailingAnchor),
            bars.bottomAnchor.constraint(equalTo: chartContainer.bottomAnchor),

            filteredEmptyLabel.centerXAnchor.constraint(equalTo: chartContainer.centerXAnchor),
            filteredEmptyLabel.centerYAnchor.constraint(equalTo: chartContainer.centerYAnchor),
            filteredEmptyLabel.leadingAnchor.constraint(greaterThanOrEqualTo: chartContainer.leadingAnchor, constant: Theme.Space.lg),
            filteredEmptyLabel.trailingAnchor.constraint(lessThanOrEqualTo: chartContainer.trailingAnchor, constant: -Theme.Space.lg),

            // 내역 카드
            breakdownCard.topAnchor.constraint(equalTo: chartCard.bottomAnchor, constant: Theme.Space.md),
            breakdownCard.leadingAnchor.constraint(equalTo: chartCard.leadingAnchor),
            breakdownCard.trailingAnchor.constraint(equalTo: chartCard.trailingAnchor),
            breakdownCard.bottomAnchor.constraint(equalTo: cg.bottomAnchor, constant: -Theme.Space.md),

            breakdownTitle.topAnchor.constraint(equalTo: breakdownCard.topAnchor, constant: Theme.Space.lg),
            breakdownTitle.leadingAnchor.constraint(equalTo: breakdownCard.leadingAnchor, constant: Theme.Space.lg),

            breakdownStack.topAnchor.constraint(equalTo: breakdownTitle.bottomAnchor, constant: Theme.Space.sm),
            breakdownStack.leadingAnchor.constraint(equalTo: breakdownCard.leadingAnchor, constant: Theme.Space.lg),
            breakdownStack.trailingAnchor.constraint(equalTo: breakdownCard.trailingAnchor, constant: -Theme.Space.lg),
            breakdownStack.bottomAnchor.constraint(equalTo: breakdownCard.bottomAnchor, constant: -Theme.Space.lg),

            emptyView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            emptyView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            emptyView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            emptyView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])
    }

    // MARK: Data
    @objc private func reload() {
        let totals = ExpenseStore.shared.totals(year: year, month: month, excludingFixed: excludeFixed)
        let total = ExpenseStore.shared.totalAmount(year: year, month: month, excludingFixed: excludeFixed)
        let rawTotal = ExpenseStore.shared.totalAmount(year: year, month: month)
        monthButton.configuration?.title = "\(year)년 \(month)월"
        todayButton.isHidden = (year == Date().year && month == Date().month)

        // 데이터 유무는 원본(필터 무관) 기준 — 고정지출만 있는 달에서도 카드·토글 유지
        let hasData = rawTotal > 0
        let hasFilteredData = total > 0
        emptyView.isHidden = hasData
        emptyView.isUserInteractionEnabled = !hasData
        // 데이터 없으면 카드를 통째로 숨기고 emptyView만 표시 (빈 카드 잔존·길이 유지 방지)
        chartCard.isHidden = !hasData
        breakdownCard.isHidden = !hasData || !hasFilteredData   // 필터로 비면 내역 카드도 숨김
        donut.isHidden = !hasFilteredData || modeControl.selectedSegmentIndex != 0
        bars.isHidden  = !hasFilteredData || modeControl.selectedSegmentIndex != 1
        // 데이터는 있으나 고정지출 제외로 표시할 게 없을 때 안내
        filteredEmptyLabel.isHidden = !(hasData && !hasFilteredData)
        modeControl.isHidden = !hasData
        breakdownStack.isHidden = !hasData
        fixedFilterButton.isHidden = !hasData
        updateFixedFilterAppearance()

        guard hasData else {
            // 펼쳐둔 행이 남지 않도록 비우고 상태 초기화
            expandedCategories.removeAll()
            breakdownStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
            return
        }

        // 필터 결과가 비면 차트·내역은 비우고 안내만
        guard hasFilteredData else {
            expandedCategories.removeAll()
            breakdownStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
            return
        }
        donut.setData(totals: totals, total: total)
        bars.setData(totals: totals, total: total)
        rebuildLegend(totals: totals)
        legendStack.isHidden = !hasFilteredData || modeControl.selectedSegmentIndex != 0

        // breakdown 갱신
        lastTotals = totals
        lastTotal = total
        rebuildBreakdown()
    }

    @objc private func toggleFixedFilter() {
        Haptic.selection()
        excludeFixed.toggle()
        reload()
    }

    private func updateFixedFilterAppearance() {
        // 회색 필 = 꺼짐, 파란 틴트 = 켜짐 (입력 화면 칩과 동일한 언어)
        fixedFilterButton.backgroundColor = excludeFixed ? Theme.Color.pointSoft : Theme.Color.groupedBG
        fixedFilterButton.configuration?.baseForegroundColor = excludeFixed ? Theme.Color.point : Theme.Color.subText
    }

    @objc private func modeChanged() {
        Haptic.selection()
        let donutMode = modeControl.selectedSegmentIndex == 0
        UIView.transition(with: view, duration: 0.25, options: .transitionCrossDissolve) {
            self.donut.isHidden = !donutMode
            self.bars.isHidden = donutMode
            self.legendStack.isHidden = !donutMode
        }
        reload()
    }

    /// 도넛 범례 갱신 — 금액 있는 카테고리만 색점+이름
    private func rebuildLegend(totals: [Category: Int]) {
        legendStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for cat in Category.allCases where (totals[cat] ?? 0) > 0 {
            let dot = UIView()
            dot.backgroundColor = cat.color
            dot.layer.cornerRadius = 4
            dot.translatesAutoresizingMaskIntoConstraints = false
            dot.widthAnchor.constraint(equalToConstant: 8).isActive = true
            dot.heightAnchor.constraint(equalToConstant: 8).isActive = true

            let name = UILabel()
            name.text = cat.rawValue
            name.font = Theme.Font.caption(12)
            name.textColor = Theme.Color.subText

            let row = UIStackView(arrangedSubviews: [dot, name])
            row.axis = .horizontal
            row.spacing = 5
            row.alignment = .center
            legendStack.addArrangedSubview(row)
        }
    }

    @objc private func prevMonth() { shift(-1) }
    @objc private func nextMonth() { shift(+1) }

    @objc private func jumpToToday() {
        Haptic.selection()
        let t = Date()
        year = t.year; month = t.month
        reload()
    }

    @objc private func showMonthPicker() {
        Haptic.selection()
        let vc = MonthPickerViewController(year: year, month: month)
        vc.onSelect = { [weak self] y, m in
            guard let self = self else { return }
            self.year = y; self.month = m
            self.reload()
        }
        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .pageSheet
        present(nav, animated: true)
    }
    private func shift(_ d: Int) {
        Haptic.selection()
        var c = DateComponents(); c.year = year; c.month = month + d
        if let date = Calendar.current.date(from: c) {
            year = date.year; month = date.month; reload()
        }
    }
}
