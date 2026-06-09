// Store/RecurringStore.swift
import Foundation
import SwiftData

extension Notification.Name {
    static let recurringDidChange = Notification.Name("recurringDidChange")
}

/// 고정지출(반복 규칙) 저장소.
/// 결제일이 지난 활성 규칙은 자동으로 ExpenseStore에 실제 지출을 생성한다.
/// 중복 방지는 ledger 대신 SwiftData를 직접 조회한다(single source of truth).
@MainActor
final class RecurringStore {

    static let shared = RecurringStore()
    private init() { load() }

    private var context: ModelContext { PocketBookContainer.shared.context }

    private(set) var items: [RecurringExpense] = []

    // MARK: - CRUD
    func add(_ r: RecurringExpense) {
        context.insert(r)
        persistItems()
        materializeDueExpenses()
        broadcast()
    }

    func update(_ r: RecurringExpense) {
        // @Model 참조 타입 — 프로퍼티 수정 후 save만 하면 됨
        persistItems()
        broadcast()
    }

    func delete(id: UUID) {
        guard let target = items.first(where: { $0.id == id }) else { return }
        context.delete(target)
        persistItems()
        broadcast()
    }

    func setActive(_ active: Bool, id: UUID) {
        guard let target = items.first(where: { $0.id == id }) else { return }
        target.isActive = active
        persistItems()
        broadcast()
    }

    func item(id: UUID) -> RecurringExpense? { items.first { $0.id == id } }

    // MARK: - 자동 생성 (materialization)
    /// 자동 생성 결과 — 스텔스 안내 토스트용
    struct MaterializeResult {
        let count: Int             // 이번에 새로 생성된 지출 건수
        let firstName: String?     // 대표 이름 (가장 먼저 생성된 항목)
        var isEmpty: Bool { count == 0 }
    }

    /// 이번 달 결제일이 지난(또는 오늘인) 활성 규칙을 실제 지출로 생성.
    /// 이미 생성됐는지는 ExpenseStore(SwiftData)에 직접 질의 — ledger 불필요.
    /// - Returns: 새로 생성된 건수와 대표 이름 (토스트 안내용)
    @discardableResult
    func materializeDueExpenses() -> MaterializeResult {
        let now = Date()
        let year = now.year, month = now.month, day = now.day

        var newExpenses: [Expense] = []
        var firstName: String?
        for r in items where r.isActive {
            guard r.chargeDay(year: year, month: month) <= day else { continue }
            guard !ExpenseStore.shared.hasMaterialized(recurringID: r.id, year: year, month: month) else { continue }
            if firstName == nil { firstName = r.name }
            newExpenses.append(Expense(
                category: r.category,
                amount: r.amount,
                memo: r.name,
                date: r.chargeDate(year: year, month: month),
                tags: r.tags,
                isFixed: true,
                recurringID: r.id))
        }
        ExpenseStore.shared.addBatch(newExpenses)   // save·통지 1회
        return MaterializeResult(count: newExpenses.count, firstName: firstName)
    }

    // MARK: - 이번 달 요약 (허브 화면용)
    var activeItems: [RecurringExpense] { items.filter { $0.isActive } }

    func monthlyTotal() -> Int { activeItems.reduce(0) { $0 + $1.amount } }

    func recordedTotal() -> Int {
        let now = Date()
        return activeItems
            .filter { $0.chargeDay(year: now.year, month: now.month) <= now.day }
            .reduce(0) { $0 + $1.amount }
    }

    func pendingTotal() -> Int { monthlyTotal() - recordedTotal() }

    func isRecordedThisMonth(_ r: RecurringExpense) -> Bool {
        let now = Date()
        return r.chargeDay(year: now.year, month: now.month) <= now.day
    }

    // MARK: - Persistence
    private func persistItems() {
        do {
            try context.save()
            load()
        } catch {
            print("⚠️ RecurringStore save error:", error)
        }
    }

    func load() {
        do {
            let descriptor = FetchDescriptor<RecurringExpense>(
                sortBy: [SortDescriptor(\.name)]
            )
            items = try context.fetch(descriptor)
        } catch {
            print("⚠️ RecurringStore load error:", error)
            items = []
        }
    }

    private func broadcast() {
        NotificationCenter.default.post(name: .recurringDidChange, object: nil)
    }
}
