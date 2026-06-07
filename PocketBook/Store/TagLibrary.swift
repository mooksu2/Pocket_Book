import Foundation

enum TagLibrary {
    static let presets: [Category: [String]] = [
        .food:      ["아침", "점심", "저녁", "장보기", "배달", "카페", "외식", "야식", "간식", "술", "디저트"],
        .transport: ["대중교통", "택시", "주유", "주차", "통행료", "정비", "항공"],
        .culture:   ["영화", "공연", "전시", "OTT", "도서", "게임", "운동", "취미", "여행"],
        .etc:       ["생필품", "의류", "미용", "의료", "통신비", "구독", "경조사", "선물", "반려동물"]
    ]
    private static let key = "tagFrequency"

    /// 해당 카테고리에서 자주 쓴 태그 (많이 쓴 순)
    static func frequent(for category: Category, limit: Int = 4) -> [String] {
        let dict = UserDefaults.standard.dictionary(forKey: key) as? [String: Int] ?? [:]
        return dict
            .filter { $0.key.hasPrefix("\(category.rawValue):") }
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .compactMap { $0.key.components(separatedBy: ":").last }
    }

    /// 지출 저장 시 사용한 태그 빈도 기록
    static func record(_ tags: [String], for category: Category) {
        guard !tags.isEmpty else { return }
        var dict = UserDefaults.standard.dictionary(forKey: key) as? [String: Int] ?? [:]
        tags.forEach { dict["\(category.rawValue):\($0)", default: 0] += 1 }
        UserDefaults.standard.set(dict, forKey: key)
    }
}
