import Foundation
import SwiftData

extension Notification.Name {
    static let recurringDidChange = Notification.Name("recurringDidChange")
}

/// 고정지출(반복 규칙) 저장소.
/// 결제일이 지난 활성 규칙은 자동으로 ExpenseStore에 실제 지출을 생성한다(중복 방지 원장 사용).
@MainActor
final class RecurringStore {

    static let shared = RecurringStore()
    private init() { load() }

    private var context: ModelContext { PocketBookContainer.shared.context }

    // ledger는 단순 문자열 Set → UserDefaults 유지 (SwiftData 전환 불필요)
    private let ledgerKey = "recurringMaterialized"
    private var ledger: Set<String> = []

    private(set) var items: [RecurringExpense] = []

    // MARK: - 현재 연·월·일 헬퍼
    private func currentYMD() -> (year: Int, month: Int, day: Int) {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        return (c.year ?? 0, c.month ?? 0, c.day ?? 1)
    }

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
    func materializeDueExpenses() {
        let t = currentYMD()
        for r in items where r.isActive {
            let key = ledgerKeyString(r.id, year: t.year, month: t.month)
            guard !ledger.contains(key) else { continue }
            guard r.chargeDay(year: t.year, month: t.month) <= t.day else { continue }
            let e = Expense(category: r.category,
                            amount: r.amount,
                            memo: r.name,
                            date: r.chargeDate(year: t.year, month: t.month),
                            tags: r.tags,
                            isFixed: true,
                            recurringID: r.id)
            ExpenseStore.shared.add(e)
            ledger.insert(key)
        }
        persistLedger()
    }

    // MARK: - 이번 달 요약 (허브 화면용)
    var activeItems: [RecurringExpense] { items.filter { $0.isActive } }

    func monthlyTotal() -> Int { activeItems.reduce(0) { $0 + $1.amount } }

    func recordedTotal() -> Int {
        let t = currentYMD()
        return activeItems
            .filter { $0.chargeDay(year: t.year, month: t.month) <= t.day }
            .reduce(0) { $0 + $1.amount }
    }

    func pendingTotal() -> Int { monthlyTotal() - recordedTotal() }

    func isRecordedThisMonth(_ r: RecurringExpense) -> Bool {
        let t = currentYMD()
        return r.chargeDay(year: t.year, month: t.month) <= t.day
    }

    // MARK: - Ledger (중복 생성 방지 원장) — UserDefaults 유지
    private func ledgerKeyString(_ id: UUID, year: Int, month: Int) -> String {
        "\(id.uuidString):\(year)-\(month)"
    }
    private func markMaterialized(_ id: UUID, year: Int, month: Int) {
        ledger.insert(ledgerKeyString(id, year: year, month: month))
        persistLedger()
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

    private func persistLedger() {
        UserDefaults.standard.set(Array(ledger), forKey: ledgerKey)
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
        if let arr = UserDefaults.standard.array(forKey: ledgerKey) as? [String] {
            ledger = Set(arr)
        }
    }

    private func broadcast() {
        NotificationCenter.default.post(name: .recurringDidChange, object: nil)
    }
}
