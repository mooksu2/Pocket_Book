// Store/Storage.swift
import Foundation

/// 로컬 영속 저장소의 키와 UserDefaults 접근 지점.
/// expenses, recurring 데이터는 SwiftData로 이전 — 여기선 설정값 키만 관리.
enum Storage {
    static var defaults: UserDefaults { .standard }

    enum Key {
        static let monthlyBudget     = "pocketbook.monthlyBudget"
        static let iCloudSync        = "pocketbook.iCloudSyncEnabled"
        static let notifications     = "pocketbook.notificationsEnabled"
        static let lastNotifiedLevel = "pocketbook.lastNotifiedLevel"
    }
}
