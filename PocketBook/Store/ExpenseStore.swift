// Store/ExpenseStore.swift
import Foundation

extension Notification.Name {
    static let expensesDidChange = Notification.Name("expensesDidChange")
}

// MARK: - ExpenseStore (Singleton · Business Logic Layer)
final class ExpenseStore {

    static let shared = ExpenseStore()
    private init() { load() }

    private var defaults: UserDefaults { Storage.defaults }
    private let key = Storage.Key.expenses
    private(set) var expenses: [Expense] = []

    // MARK: CRUD
    func add(_ expense: Expense) {
        expenses.append(expense)
        persist()
    }

    func update(_ expense: Expense) {
        guard let i = expenses.firstIndex(where: { $0.id == expense.id }) else { return }
        expenses[i] = expense
        persist()
    }

    func delete(id: UUID) {
        expenses.removeAll { $0.id == id }
        persist()
    }

    // MARK: Queries
    func expenses(year: Int, month: Int) -> [Expense] {
        let cal = Calendar.current
        return expenses
            .filter {
                let c = cal.dateComponents([.year, .month], from: $0.date)
                return c.year == year && c.month == month
            }
            .sorted { $0.date > $1.date }
    }

    /// 날짜별 그룹 (최신 날짜 우선)
    func daySections(year: Int, month: Int) -> [DaySection] {
        let cal = Calendar.current
        let monthly = expenses(year: year, month: month)
        let grouped = Dictionary(grouping: monthly) { cal.startOfDay(for: $0.date) }
        return grouped
            .map { DaySection(date: $0.key, expenses: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.date > $1.date }
    }

    func totals(year: Int, month: Int) -> [Category: Int] {
        let list = expenses(year: year, month: month)
        var result: [Category: Int] = [:]
        for cat in Category.allCases {
            result[cat] = list.filter { $0.category == cat }.reduce(0) { $0 + $1.amount }
        }
        return result
    }

    func totalAmount(year: Int, month: Int) -> Int {
        expenses(year: year, month: month).reduce(0) { $0 + $1.amount }
    }

    /// 이번(해당) 달의 예산 진행 상태. 예산 미설정이면 nil.
    func budgetStatus(year: Int, month: Int) -> BudgetStatus? {
        let budget = SettingsStore.shared.monthlyBudget
        guard budget > 0 else { return nil }
        return BudgetStatus(budget: budget, spent: totalAmount(year: year, month: month))
    }

    func insight(year: Int, month: Int) -> MonthlyInsight {
        let cal = Calendar.current
        let list = totals(year: year, month: month)
        let top  = list.max { $0.value < $1.value }
        let monthly = expenses(year: year, month: month)
        let distinctDays = Set(monthly.map { cal.startOfDay(for: $0.date) }).count
        let total = monthly.reduce(0) { $0 + $1.amount }
        let avg = distinctDays > 0 ? total / distinctDays : 0
        return MonthlyInsight(
            topCategory:  (top?.value ?? 0) > 0 ? top?.key : nil,
            topAmount:    top?.value ?? 0,
            dayCount:     distinctDays,
            entryCount:   monthly.count,
            dailyAverage: avg
        )
    }

    /// 지난달 같은 기간 대비 비교. 현재 달이면 "오늘까지", 과거 달이면 "월 전체" 기준.
    func comparison(year: Int, month: Int) -> MonthComparison {
        let cal = Calendar.current
        let now = Date()
        let isCurrent = (year == now.year && month == now.month)

        var c = DateComponents(); c.year = year; c.month = month; c.day = 1
        let firstOfMonth = cal.date(from: c) ?? now
        let monthLen = cal.range(of: .day, in: .month, for: firstOfMonth)?.count ?? 30
        let cutoff = isCurrent ? cal.component(.day, from: now) : monthLen
        let cur = sum(year: year, month: month, throughDay: cutoff)

        var pc = DateComponents(); pc.year = year; pc.month = month - 1; pc.day = 1
        let prevFirst = cal.date(from: pc) ?? now
        let pYear = cal.component(.year, from: prevFirst)
        let pMonth = cal.component(.month, from: prevFirst)
        let prevLen = cal.range(of: .day, in: .month, for: prevFirst)?.count ?? 30
        let prev = sum(year: pYear, month: pMonth, throughDay: min(cutoff, prevLen))

        return MonthComparison(currentToDate: cur, previousToDate: prev, isCurrentMonth: isCurrent)
    }

    /// 해당 달의 1일부터 day일까지 누적 지출.
    private func sum(year: Int, month: Int, throughDay day: Int) -> Int {
        let cal = Calendar.current
        return expenses.filter {
            let c = cal.dateComponents([.year, .month, .day], from: $0.date)
            return c.year == year && c.month == month && (c.day ?? 99) <= day
        }.reduce(0) { $0 + $1.amount }
    }

    // MARK: Calendar queries
    /// 해당 달의 '일(day) → 그날 총 지출' 매핑.
    func dailyTotals(year: Int, month: Int) -> [Int: Int] {
        let cal = Calendar.current
        var result: [Int: Int] = [:]
        for e in expenses(year: year, month: month) {
            let d = cal.component(.day, from: e.date)
            result[d, default: 0] += e.amount
        }
        return result
    }

    /// 해당 달의 '일(day) → 그날 가장 많이 쓴 카테고리' (달력 점 색상용).
    func dailyTopCategory(year: Int, month: Int) -> [Int: Category] {
        let cal = Calendar.current
        var byDay: [Int: [Category: Int]] = [:]
        for e in expenses(year: year, month: month) {
            let d = cal.component(.day, from: e.date)
            byDay[d, default: [:]][e.category, default: 0] += e.amount
        }
        var result: [Int: Category] = [:]
        for (day, cats) in byDay {
            if let top = cats.max(by: { $0.value < $1.value })?.key { result[day] = top }
        }
        return result
    }
    
    /// 카테고리 내 태그별 합계. 태그 없는 지출은 "태그 없음"으로 묶음.
    /// 한 지출에 태그가 여러 개면 각 태그에 전액을 귀속(필터 합계 개념).
    func tagTotals(year: Int, month: Int, category: Category) -> [(tag: String, amount: Int)] {
        let items = expenses(year: year, month: month).filter { $0.category == category }
        var dict: [String: Int] = [:]
        for e in items {
            if e.tags.isEmpty {
                dict["태그 없음", default: 0] += e.amount
            } else {
                for t in e.tags { dict[t, default: 0] += e.amount }
            }
        }
        return dict.sorted { $0.value > $1.value }.map { (tag: $0.key, amount: $0.value) }
    }
    
    /// 특정 날짜(하루)의 지출 목록 (시간 역순).
    func expenses(on date: Date) -> [Expense] {
        let cal = Calendar.current
        return expenses
            .filter { cal.isDate($0.date, inSameDayAs: date) }
            .sorted { $0.date > $1.date }
    }

    // MARK: Persistence (Codable + UserDefaults · App Group 공유)
    private func persist() {
        do {
            let data = try JSONEncoder().encode(expenses)
            defaults.set(data, forKey: key)
            CloudSyncService.shared.push(data)          // iCloud 업로드 (P3)
        } catch {
            print("⚠️ ExpenseStore save error:", error)
        }
        broadcastChange()
    }

    private func load() {
        guard let data = defaults.data(forKey: key) else { return }
        do {
            expenses = try JSONDecoder().decode([Expense].self, from: data)
        } catch {
            print("⚠️ decode failed — fallback to empty:", error)
            expenses = []
        }
    }

    /// 외부(다른 기기 iCloud 등)에서 디스크가 바뀐 뒤 메모리 상태를 다시 읽는다.
    func reloadFromDisk() {
        load()
        broadcastChange()
    }

    /// 변경을 화면에 전파.
    private func broadcastChange() {
        NotificationCenter.default.post(name: .expensesDidChange, object: nil)
    }

    // MARK: Demo seeding (최초 실행 시 데모 데이터)
    func seedDemoDataIfEmpty() {
        guard expenses.isEmpty else { return }
        let cal = Calendar.current
        let now = Date()
        func day(_ offset: Int, _ h: Int) -> Date {
            let base = cal.date(byAdding: .day, value: -offset, to: now)!
            return cal.date(bySettingHour: h, minute: 0, second: 0, of: base)!
        }
        // 지난달 같은 기간(1~5일) 데이터 — 월 이동·전월 대비 비교 시연용
        func prevMonthDay(_ d: Int, _ h: Int) -> Date {
            let pm = cal.date(byAdding: .month, value: -1, to: now)!
            var c = DateComponents()
            c.year = cal.component(.year, from: pm)
            c.month = cal.component(.month, from: pm)
            c.day = d; c.hour = h
            return cal.date(from: c) ?? now
        }
        expenses = [
            Expense(category: .food,      amount: 8500,  memo: "점심 김치찌개", date: day(0, 12)),
            Expense(category: .transport, amount: 1450,  memo: "지하철",       date: day(0, 9)),
            Expense(category: .culture,   amount: 15000, memo: "영화 ‘듄’",    date: day(1, 19)),
            Expense(category: .food,      amount: 4200,  memo: "편의점",       date: day(1, 22)),
            Expense(category: .food,      amount: 12000, memo: "저녁 외식",    date: day(2, 18)),
            Expense(category: .etc,       amount: 3200,  memo: "문구류",       date: day(3, 15)),
            Expense(category: .transport, amount: 6800,  memo: "택시",        date: day(4, 23)),
            Expense(category: .culture,   amount: 10900, memo: "도서 구입",    date: day(5, 14)),
            // ── 지난달 ──
            Expense(category: .food,      amount: 9000,  memo: "브런치",       date: prevMonthDay(2, 12)),
            Expense(category: .culture,   amount: 28000, memo: "콘서트 예매",  date: prevMonthDay(3, 19)),
            Expense(category: .transport, amount: 8000,  memo: "KTX",         date: prevMonthDay(4, 9)),
            Expense(category: .food,      amount: 11000, memo: "회식",        date: prevMonthDay(5, 13)),
            Expense(category: .etc,       amount: 19000, memo: "생활용품",     date: prevMonthDay(5, 16)),
        ]
        persist()
    }
}
