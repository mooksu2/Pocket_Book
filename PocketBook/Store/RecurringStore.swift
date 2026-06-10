// Store/RecurringStore.swift
import Foundation
import SwiftData

extension Notification.Name {
    static let recurringDidChange = Notification.Name("recurringDidChange")
}

/// 고정지출(반복 규칙) 저장소.
/// 결제일이 지난 활성 규칙은 자동으로 ExpenseStore에 실제 지출을 생성한다.
/// 중복 방지: SwiftData의 실제 지출 존재 여부(hasMaterialized)
/// + 규칙별 skippedMonths(사용자가 그 달 자동 생성분을 삭제한 기록).
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

    /// 수정 화면에서 live @Model의 프로퍼티를 직접 바꾼 뒤 호출.
    /// 저장 → 이번 달 미생성분 즉시 반영(materialize) → 통지.
    /// (파라미터를 받고 무시하던 update(_:)는 폐기 — 수정이 디스크에 저장되지 않던 버그의 원인)
    func saveChanges() {
        persistItems()
        materializeDueExpenses()
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

    // MARK: - 이 달 건너뛰기 (사용자 삭제 의사 기록)
    /// 자동 생성된 지출을 사용자가 삭제했을 때 ExpenseStore가 호출 — 같은 달 재생성(좀비 부활)을 막는다.
    func skipMonth(recurringID: UUID, date: Date) {
        guard let r = item(id: recurringID) else { return }
        let key = RecurringExpense.monthKey(year: date.year, month: date.month)
        guard !r.skippedMonths.contains(key) else { return }
        r.skippedMonths.append(key)
        persistItems()   // UI에 보이는 값이 아니므로 broadcast는 생략
    }

    /// 삭제 되돌리기(Undo)로 지출이 복원될 때 건너뛰기 기록 해제.
    func unskipMonth(recurringID: UUID, date: Date) {
        guard let r = item(id: recurringID) else { return }
        let key = RecurringExpense.monthKey(year: date.year, month: date.month)
        guard r.skippedMonths.contains(key) else { return }
        r.skippedMonths.removeAll { $0 == key }
        persistItems()
    }

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
        let monthKey = RecurringExpense.monthKey(year: year, month: month)

        var newExpenses: [Expense] = []
        var firstName: String?
        for r in items where r.isActive {
            guard r.chargeDay(year: year, month: month) <= day else { continue }
            guard !r.skippedMonths.contains(monthKey) else { continue }   // 사용자가 이 달 삭제(건너뜀)
            guard !ExpenseStore.shared.hasMaterialized(recurringID: r.id, year: year, month: month) else { continue }
            if firstName == nil, !r.name.isEmpty { firstName = r.name }   // 메모 없는 항목은 대표 이름에서 제외
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
