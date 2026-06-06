// Store/SettingsStore.swift
import Foundation

extension Notification.Name {
    static let settingsDidChange = Notification.Name("settingsDidChange")
}

/// 예산·동기화·알림 설정을 보관하는 싱글톤. (P3)
final class SettingsStore {

    static let shared = SettingsStore()
    private init() {}

    private var defaults: UserDefaults { Storage.defaults }

    // MARK: 월 예산 (0 = 미설정)
    var monthlyBudget: Int {
        get { defaults.integer(forKey: Storage.Key.monthlyBudget) }
        set {
            defaults.set(newValue, forKey: Storage.Key.monthlyBudget)
            notifyChange()
        }
    }
    var hasBudget: Bool { monthlyBudget > 0 }

    // MARK: iCloud 동기화 사용 여부
    var iCloudSyncEnabled: Bool {
        get { defaults.bool(forKey: Storage.Key.iCloudSync) }
        set {
            defaults.set(newValue, forKey: Storage.Key.iCloudSync)
            notifyChange()
        }
    }

    // MARK: 예산 초과 알림 사용 여부
    var notificationsEnabled: Bool {
        get { defaults.bool(forKey: Storage.Key.notifications) }
        set {
            defaults.set(newValue, forKey: Storage.Key.notifications)
            notifyChange()
        }
    }

    private func notifyChange() {
        NotificationCenter.default.post(name: .settingsDidChange, object: nil)
    }
}

// MARK: - Budget Status (예산 진행 상태 계산)
struct BudgetStatus {
    let budget: Int
    let spent: Int

    var remaining: Int { budget - spent }
    var isOver: Bool { spent > budget }
    /// 0.0 ~ 1.0+ (초과 시 1.0 넘김)
    var ratio: Double {
        guard budget > 0 else { return 0 }
        return Double(spent) / Double(budget)
    }
    var clampedRatio: Double { min(ratio, 1.0) }
    var percent: Int { Int((ratio * 100).rounded()) }

    /// 알림/색상 단계: 0 안전(<80%) · 1 주의(80~99%) · 2 초과(>=100%)
    var level: Int {
        if ratio >= 1.0 { return 2 }
        if ratio >= 0.8 { return 1 }
        return 0
    }
}
