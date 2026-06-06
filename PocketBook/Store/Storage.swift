// Store/Storage.swift
import Foundation

/// 로컬 영속 저장소의 키와 UserDefaults 접근 지점.
enum Storage {
    static var defaults: UserDefaults { .standard }

    enum Key {
        static let expenses          = "pocketbook.expenses"
        static let monthlyBudget     = "pocketbook.monthlyBudget"
        static let iCloudSync        = "pocketbook.iCloudSyncEnabled"
        static let notifications     = "pocketbook.notificationsEnabled"
        static let lastNotifiedLevel = "pocketbook.lastNotifiedLevel"
    }
}
