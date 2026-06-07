// Models/Expense.swift
import UIKit

// MARK: - Category
enum Category: String, CaseIterable, Codable {
    case food      = "식비"
    case transport = "교통"
    case culture   = "문화"
    case etc       = "기타"

    var color: UIColor {
        switch self {
        case .food:      return UIColor(hex: "#FFB74D")
        case .transport: return UIColor(hex: "#64B5F6")
        case .culture:   return UIColor(hex: "#BA68C8")
        case .etc:       return UIColor(hex: "#9E9E9E")
        }
    }

    /// 그라데이션 채움용 (밝은 → 진한)
    var gradient: [UIColor] {
        switch self {
        case .food:      return [UIColor(hex: "#FFCC80"), UIColor(hex: "#FB8C00")]
        case .transport: return [UIColor(hex: "#90CAF9"), UIColor(hex: "#1E88E5")]
        case .culture:   return [UIColor(hex: "#CE93D8"), UIColor(hex: "#8E24AA")]
        case .etc:       return [UIColor(hex: "#BDBDBD"), UIColor(hex: "#757575")]
        }
    }

    var symbolName: String {
        switch self {
        case .food:      return "cart.fill"
        case .transport: return "tram.fill"
        case .culture:   return "film.fill"
        case .etc:       return "ellipsis.circle.fill"
        }
    }
}

// MARK: - Expense
struct Expense: Codable, Identifiable, Equatable {
    var id:       UUID
    var category: Category
    var amount:   Int
    var memo:     String
    var date:     Date
    var tags:     [String]
    var isFixed:  Bool

    init(id: UUID = UUID(), category: Category, amount: Int,
         memo: String = "", date: Date = Date(),
         tags: [String] = [], isFixed: Bool = false) {
        self.id = id; self.category = category; self.amount = amount
        self.memo = memo; self.date = date
        self.tags = tags; self.isFixed = isFixed
    }

    
    enum CodingKeys: String, CodingKey {
        case id, category, amount, memo, date, tags, isFixed
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id       = try c.decode(UUID.self,     forKey: .id)
        category = try c.decode(Category.self, forKey: .category)
        amount   = try c.decode(Int.self,      forKey: .amount)
        memo     = try c.decode(String.self,   forKey: .memo)
        date     = try c.decode(Date.self,     forKey: .date)
        tags     = try c.decodeIfPresent([String].self, forKey: .tags)    ?? []
        isFixed  = try c.decodeIfPresent(Bool.self,     forKey: .isFixed) ?? false
    }
}
// MARK: - Daily Section (리스트 그룹핑용)
struct DaySection {
    let date: Date
    let expenses: [Expense]
    var total: Int { expenses.reduce(0) { $0 + $1.amount } }
}

// MARK: - Monthly Insight (통계 요약 문구)
struct MonthlyInsight {
    let topCategory: Category?
    let topAmount: Int
    let dayCount: Int          // 지출이 발생한 날의 수
    let entryCount: Int
    let dailyAverage: Int

    var headline: String {
        guard let top = topCategory, topAmount > 0 else {
            return "이번 달은 아직 지출이 없어요"
        }
        return "이번 달엔 ‘\(top.rawValue)’에 가장 많이 썼어요"
    }
}

// MARK: - Month-over-Month Comparison (지난달 대비)
struct MonthComparison {
    let currentToDate: Int     // 이번 달 (현재 달이면 오늘까지) 누적
    let previousToDate: Int    // 지난달 같은 기간 누적
    let isCurrentMonth: Bool

    var hasPrevious: Bool { previousToDate > 0 }
    var delta: Int { currentToDate - previousToDate }
    var ratio: Double { previousToDate > 0 ? Double(delta) / Double(previousToDate) : 0 }
    var percent: Int { abs(Int((ratio * 100).rounded())) }
    var isUp: Bool { delta > 0 }
    var isFlat: Bool { hasPrevious && percent == 0 }
}
