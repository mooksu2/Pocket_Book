// Store/ExpenseStore.swift
import Foundation
import SwiftData

extension Notification.Name {
    static let expensesDidChange = Notification.Name("expensesDidChange")
}

// MARK: - ExpenseStore (Singleton · Business Logic Layer)
@MainActor
final class ExpenseStore {

    static let shared = ExpenseStore()
    private init() { load() }

    private var context: ModelContext { PocketBookContainer.shared.context }
    private(set) var expenses: [Expense] = []

    // MARK: CRUD
    func add(_ expense: Expense) {
        context.insert(expense)
        do {
            try context.save()
            expenses.append(expense)   // 디스크 재조회 없이 캐시에 직접 반영
            resort()
            // 자동 생성분 복원(Undo)이면 '이 달 건너뛰기' 기록 해제
            if let rid = expense.recurringID {
                RecurringStore.shared.unskipMonth(recurringID: rid, date: expense.date)
            }
        } catch {
            print("⚠️ ExpenseStore save error:", error)
            load()   // 실패 시에만 전체 재조회로 정합성 복구
        }
        broadcastChange()
    }

    /// 여러 건을 한 번에 insert — save·통지는 1회만 (materialize 전용)
    func addBatch(_ list: [Expense]) {
        guard !list.isEmpty else { return }
        list.forEach { context.insert($0) }
        do {
            try context.save()
            expenses.append(contentsOf: list)
            resort()
        } catch {
            print("⚠️ ExpenseStore batch save error:", error)
            load()
        }
        broadcastChange()
    }

    /// 수정 화면 등에서 live @Model의 프로퍼티를 직접 바꾼 뒤 호출 — 저장 + 정렬 + 통지.
    /// (임시 @Model을 만들어 필드를 복사하던 update(_:)는 폐기 — recurringID 유실·삭제분 부활 버그의 원인)
    func saveChanges() {
        do {
            try context.save()
            resort()   // 캐시는 같은 참조라 정렬만 갱신하면 된다
        } catch {
            print("⚠️ ExpenseStore save error:", error)
            load()
        }
        broadcastChange()
    }

    func delete(id: UUID) {
        guard let target = expenses.first(where: { $0.id == id }) else { return }
        // 삭제 후엔 객체 접근이 불안전하므로 필요한 값을 미리 보관
        let recurringID = target.recurringID
        let chargeDate  = target.date
        context.delete(target)
        do {
            try context.save()
            expenses.removeAll { $0.id == id }
            // 자동 생성분 삭제 = '이 달은 건너뛰기' — foreground 복귀 시 재생성(좀비 부활) 방지
            if let rid = recurringID {
                RecurringStore.shared.skipMonth(recurringID: rid, date: chargeDate)
            }
        } catch {
            print("⚠️ ExpenseStore delete error:", error)
            load()
        }
        broadcastChange()
    }

    /// 해당 id의 지출이 존재하는지 (편집 화면의 삭제 여부 판별용 — modelContext nil 체크는 iOS 17에서 신뢰 불가)
    func contains(id: UUID) -> Bool { expenses.contains { $0.id == id } }

    /// 고정지출이 해당 달에 이미 생성됐는지 메모리 캐시에서 조회.
    /// 모든 변경이 @MainActor에서 캐시와 동기 갱신되므로 디스크 재조회 없이 안전하다.
    func hasMaterialized(recurringID: UUID, year: Int, month: Int) -> Bool {
        let cal = Calendar.current
        return expenses.contains {
            guard $0.recurringID == recurringID else { return false }
            let c = cal.dateComponents([.year, .month], from: $0.date)
            return c.year == year && c.month == month
        }
    }

    // MARK: Queries
    func expenses(year: Int, month: Int, excludingFixed: Bool = false) -> [Expense] {
        let cal = Calendar.current
        return expenses
            .filter {
                if excludingFixed && $0.isFixed { return false }
                let c = cal.dateComponents([.year, .month], from: $0.date)
                return c.year == year && c.month == month
            }
            .sorted { $0.date > $1.date }
    }

    func daySections(year: Int, month: Int) -> [DaySection] {
        let cal = Calendar.current
        let monthly = expenses(year: year, month: month)
        let grouped = Dictionary(grouping: monthly) { cal.startOfDay(for: $0.date) }
        return grouped
            .map { DaySection(date: $0.key, expenses: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.date > $1.date }
    }

    func totals(year: Int, month: Int, excludingFixed: Bool = false) -> [Category: Int] {
        var result = Dictionary(uniqueKeysWithValues: Category.allCases.map { ($0, 0) })
        for e in expenses(year: year, month: month, excludingFixed: excludingFixed) {
            result[e.category, default: 0] += e.amount
        }
        return result
    }

    func totalAmount(year: Int, month: Int, excludingFixed: Bool = false) -> Int {
        expenses(year: year, month: month, excludingFixed: excludingFixed).reduce(0) { $0 + $1.amount }
    }

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
        // '하루 평균'은 기록이 있는 날이 아니라 경과일 기준으로 나눈다
        // (이번 달 = 오늘까지 경과한 일수, 지난달 = 그 달의 전체 일수)
        let now = Date()
        let elapsedDays: Int
        if year == now.year && month == now.month {
            elapsedDays = now.day
        } else if let monthDate = cal.date(from: DateComponents(year: year, month: month)),
                  let range = cal.range(of: .day, in: .month, for: monthDate) {
            elapsedDays = range.count
        } else {
            elapsedDays = 0
        }
        let avg = elapsedDays > 0 ? total / elapsedDays : 0
        return MonthlyInsight(
            topCategory:  (top?.value ?? 0) > 0 ? top?.key : nil,
            topAmount:    top?.value ?? 0,
            dayCount:     distinctDays,
            entryCount:   monthly.count,
            dailyAverage: avg
        )
    }

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

    private func sum(year: Int, month: Int, throughDay day: Int) -> Int {
        let cal = Calendar.current
        return expenses.filter {
            let c = cal.dateComponents([.year, .month, .day], from: $0.date)
            return c.year == year && c.month == month && (c.day ?? 99) <= day
        }.reduce(0) { $0 + $1.amount }
    }

    func dailyTotals(year: Int, month: Int) -> [Int: Int] {
        let cal = Calendar.current
        var result: [Int: Int] = [:]
        for e in expenses(year: year, month: month) {
            let d = cal.component(.day, from: e.date)
            result[d, default: 0] += e.amount
        }
        return result
    }

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

    func tagTotals(year: Int, month: Int, category: Category, excludingFixed: Bool = false) -> [(tag: String, amount: Int)] {
        let items = expenses(year: year, month: month, excludingFixed: excludingFixed).filter { $0.category == category }
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

    func expenses(on date: Date) -> [Expense] {
        let cal = Calendar.current
        return expenses
            .filter { cal.isDate($0.date, inSameDayAs: date) }
            .sorted { $0.date > $1.date }
    }

    // MARK: Persistence
    /// 캐시 정렬만 갱신 (날짜 내림차순) — 디스크 재조회 없음
    private func resort() {
        expenses.sort { $0.date > $1.date }
    }

    func load() {
        do {
            let descriptor = FetchDescriptor<Expense>(
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            expenses = try context.fetch(descriptor)
        } catch {
            print("⚠️ ExpenseStore load error:", error)
            expenses = []
        }
    }

    func reloadFromDisk() {
        load()
        broadcastChange()
    }

    private func broadcastChange() {
        NotificationCenter.default.post(name: .expensesDidChange, object: nil)
    }
}
