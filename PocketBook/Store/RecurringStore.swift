import Foundation

extension Notification.Name {
    static let recurringDidChange = Notification.Name("recurringDidChange")
}

/// 고정지출(반복 규칙) 저장소.
/// 결제일이 지난 활성 규칙은 자동으로 ExpenseStore에 실제 지출을 생성한다(중복 방지 원장 사용).
final class RecurringStore {

    static let shared = RecurringStore()
    private init() { load() }

    private let defaults  = UserDefaults.standard
    private let itemsKey  = "recurringItems"
    private let ledgerKey = "recurringMaterialized"   // ["uuid:2026-6", ...] 한 달에 한 번만 생성

    private(set) var items: [RecurringExpense] = []
    private var ledger: Set<String> = []

    // MARK: - 현재 연·월·일 헬퍼
    private func currentYMD() -> (year: Int, month: Int, day: Int) {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        return (c.year ?? 0, c.month ?? 0, c.day ?? 1)
    }

    // MARK: - CRUD
    func add(_ r: RecurringExpense) {
        items.append(r)
        persistItems()
        // 등록 시점에 이번 달 결제일이 '이미 지난' 경우 → 소급 생성하지 않도록 건너뜀 표시
        let t = currentYMD()
        if r.chargeDay(year: t.year, month: t.month) < t.day {
            markMaterialized(r.id, year: t.year, month: t.month)
        }
        materializeDueExpenses()   // 오늘이 결제일이면 즉시 반영, 미래면 '예정'으로 남음
        broadcast()
    }

    func update(_ r: RecurringExpense) {
        guard let i = items.firstIndex(where: { $0.id == r.id }) else { return }
        items[i] = r
        persistItems()
        broadcast()
        // 수정은 '미래'에만 반영 — 이미 생성된 이번 달 기록은 건드리지 않는다.
    }

    func delete(id: UUID) {
        items.removeAll { $0.id == id }
        persistItems()
        broadcast()
        // 이미 생성된 과거 지출은 그대로 둔다(기록 보존).
    }

    func setActive(_ active: Bool, id: UUID) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        items[i].isActive = active
        persistItems()
        broadcast()
    }

    func item(id: UUID) -> RecurringExpense? { items.first { $0.id == id } }

    // MARK: - 자동 생성 (materialization)
    /// 이번 달에서 결제일이 지난(또는 오늘인) 활성 규칙을 실제 지출로 생성한다.
    func materializeDueExpenses() {
        let t = currentYMD()
        for r in items where r.isActive {
            let key = ledgerKeyString(r.id, year: t.year, month: t.month)
            guard !ledger.contains(key) else { continue }
            guard r.chargeDay(year: t.year, month: t.month) <= t.day else { continue }  // 미래 결제일은 '예정'
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

    /// 이번 달 고정지출 총액(활성 규칙 전체 합)
    func monthlyTotal() -> Int { activeItems.reduce(0) { $0 + $1.amount } }

    /// 이번 달 기준 이미 결제일이 지난(=기록됨) 합계
    func recordedTotal() -> Int {
        let t = currentYMD()
        return activeItems
            .filter { $0.chargeDay(year: t.year, month: t.month) <= t.day }
            .reduce(0) { $0 + $1.amount }
    }

    /// 이번 달 기준 아직 결제일이 안 된(=예정) 합계
    func pendingTotal() -> Int { monthlyTotal() - recordedTotal() }

    /// 특정 규칙이 이번 달 기준 이미 기록됐는지(true) / 예정인지(false)
    func isRecordedThisMonth(_ r: RecurringExpense) -> Bool {
        let t = currentYMD()
        return r.chargeDay(year: t.year, month: t.month) <= t.day
    }

    // MARK: - Ledger (중복 생성 방지 원장)
    private func ledgerKeyString(_ id: UUID, year: Int, month: Int) -> String {
        "\(id.uuidString):\(year)-\(month)"
    }
    private func markMaterialized(_ id: UUID, year: Int, month: Int) {
        ledger.insert(ledgerKeyString(id, year: year, month: month))
        persistLedger()
    }

    // MARK: - Persistence
    private func persistItems() {
        if let data = try? JSONEncoder().encode(items) {
            defaults.set(data, forKey: itemsKey)
        }
    }
    private func persistLedger() {
        defaults.set(Array(ledger), forKey: ledgerKey)
    }
    private func load() {
        if let data = defaults.data(forKey: itemsKey),
           let decoded = try? JSONDecoder().decode([RecurringExpense].self, from: data) {
            items = decoded
        }
        if let arr = defaults.array(forKey: ledgerKey) as? [String] {
            ledger = Set(arr)
        }
    }
    private func broadcast() {
        NotificationCenter.default.post(name: .recurringDidChange, object: nil)
    }
}
