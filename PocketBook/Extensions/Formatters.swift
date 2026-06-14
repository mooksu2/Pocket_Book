// Extensions/Formatters.swift
import Foundation

enum Fmt {
    static let decimal: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "ko_KR")
        return f
    }()

    // 캐시된 DateFormatter — 생성 비용이 커서 재사용 (모두 main-thread 사용이라 싱글톤 안전)
    static let time            = make("a h:mm")          // 오전 9:05
    static let monthDay        = make("M월 d일")          // 6월 5일
    static let monthDayWeekday = make("M월 d일 (E)")      // 6월 5일 (목)
    static let yyyyMd          = make("yyyy. M. d.")     // 2026. 6. 5.
    static let fullKorean      = make("yyyy년 M월 d일")   // 2026년 6월 5일

    private static func make(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = format
        return f
    }
}

extension Int {
    /// "8,500" (숫자만)
    var grouped: String { Fmt.decimal.string(from: NSNumber(value: self)) ?? "\(self)" }
    /// "₩8,500"
    var won: String { "₩" + grouped }
    /// "8,500원"
    var wonSuffix: String { grouped + "원" }
}

extension Date {
    var year:  Int { Calendar.current.component(.year,  from: self) }
    var month: Int { Calendar.current.component(.month, from: self) }
    var day:   Int { Calendar.current.component(.day,   from: self) }

    /// "오늘 · 6월 5일", "어제 · 6월 4일", "6월 3일 (화)"
    var sectionTitle: String {
        let cal = Calendar.current
        if cal.isDateInToday(self)     { return "오늘 · " + Fmt.monthDay.string(from: self) }
        if cal.isDateInYesterday(self) { return "어제 · " + Fmt.monthDay.string(from: self) }
        return Fmt.monthDayWeekday.string(from: self)
    }

    var timeShort: String { Fmt.time.string(from: self) }

    func datePickerLabel() -> String {
        let cal = Calendar.current
        let base = Fmt.fullKorean.string(from: self)
        if cal.isDateInToday(self)     { return base + " (오늘)" }
        if cal.isDateInYesterday(self) { return base + " (어제)" }
        return base
    }
}

// MARK: - 캘린더 셀용 축약 금액
extension Int {
    /// 515,000 → "51.5만", 30,000 → "3만", 9,900 → "9,900"
    var compactWon: String {
        if self >= 10_000 {
            let man = (Double(self) / 10_000 * 10).rounded() / 10
            return man.truncatingRemainder(dividingBy: 1) == 0
                ? "\(Int(man))만"
                : String(format: "%.1f만", man)
        }
        return grouped
    }
}
