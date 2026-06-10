import Foundation
import SwiftData

/// 매월 반복되는 고정지출 '규칙'. 실제 지출(Expense)은 결제일이 지나면 자동 생성된다.
@Model
final class RecurringExpense {
    @Attribute(.unique) var id:         UUID
    var name:       String
    var amount:     Int            // 원 단위
    var categoryRaw: String        // SwiftData는 enum 직접 저장 불가 → rawValue로 우회
    var dayOfMonth: Int            // 1...31 (없는 날은 말일로 보정)
    var isActive:   Bool
    var tags:       [String]
    /// 사용자가 자동 생성분을 삭제해 '이 달은 건너뛰기'로 기록한 달 키 목록 ("2026-06").
    /// 기본값이 있는 신규 프로퍼티 → 기존 데이터는 SwiftData 경량 마이그레이션으로 자동 보정된다.
    var skippedMonths: [String] = []
    
    @Transient
    var category: Category {
        get { Category(rawValue: categoryRaw) ?? .etc }
        set { categoryRaw = newValue.rawValue }
    }

    init(id: UUID = UUID(),
         name: String,
         amount: Int,
         category: Category,
         dayOfMonth: Int,
         isActive: Bool = true,
         tags: [String] = []) {
        self.id          = id
        self.name        = name
        self.amount      = amount
        self.categoryRaw = category.rawValue
        self.dayOfMonth  = max(1, min(31, dayOfMonth))
        self.isActive    = isActive
        self.tags        = tags
    }

    /// skippedMonths에 쓰는 달 키 ("2026-06").
    static func monthKey(year: Int, month: Int) -> String {
        String(format: "%04d-%02d", year, month)
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
        c.year   = year
        c.month  = month
        c.day    = chargeDay(year: year, month: month)
        c.hour   = 9
        c.minute = 0
        return cal.date(from: c) ?? Date()
    }
}
