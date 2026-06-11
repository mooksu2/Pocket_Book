// Extensions/Formatters.swift
import Foundation

enum Fmt {
    static let decimal: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "ko_KR")
        return f
    }()
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
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        if cal.isDateInToday(self) {
            f.dateFormat = "M월 d일"
            return "오늘 · " + f.string(from: self)
        } else if cal.isDateInYesterday(self) {
            f.dateFormat = "M월 d일"
            return "어제 · " + f.string(from: self)
        } else {
            f.dateFormat = "M월 d일 (E)"
            return f.string(from: self)
        }
    }

    var timeShort: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "a h:mm"
        return f.string(from: self)
    }

    func datePickerLabel() -> String {
        let cal = Calendar.current
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "yyyy년 M월 d일"
        let base = f.string(from: self)
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
