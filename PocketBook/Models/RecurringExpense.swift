import Foundation

/// 매월 반복되는 고정지출 '규칙'. 실제 지출(Expense)은 결제일이 지나면 자동 생성된다.
struct RecurringExpense: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var amount: Int            // 원 단위
    var category: Category
    var dayOfMonth: Int        // 1...31 (없는 날은 말일로 보정)
    var isActive: Bool

    init(id: UUID = UUID(),
         name: String,
         amount: Int,
         category: Category,
         dayOfMonth: Int,
         isActive: Bool = true) {
        self.id         = id
        self.name       = name
        self.amount     = amount
        self.category   = category
        self.dayOfMonth = max(1, min(31, dayOfMonth))
        self.isActive   = isActive
    }

    /// 해당 연·월의 실제 청구 '일(day)'. 말일 보정: 31일 설정 + 2월 → 28/29.
    func chargeDay(year: Int, month: Int) -> Int {
        let cal = Calendar.current
        var c = DateComponents(); c.year = year; c.month = month; c.day = 1
        let first = cal.date(from: c) ?? Date()
        let last  = cal.range(of: .day, in: .month, for: first)?.count ?? 28
        return min(dayOfMonth, last)
    }

    /// 해당 연·월의 청구 날짜(자동 생성 Expense의 date로 사용). 오전 9시로 고정.
    func chargeDate(year: Int, month: Int) -> Date {
        let cal = Calendar.current
        var c = DateComponents()
        c.year = year
        c.month = month
        c.day = chargeDay(year: year, month: month)
        c.hour = 9
        c.minute = 0
        return cal.date(from: c) ?? Date()
    }
}
