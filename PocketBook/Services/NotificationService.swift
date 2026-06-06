// Services/NotificationService.swift
import UserNotifications

/// 예산 초과 로컬 알림 (P3: 예산 설정·알림).
/// UNUserNotificationCenter로 80% 도달 / 100% 초과 시점에 1회씩 알림.
enum NotificationService {

    static func requestAuthorization(_ completion: ((Bool) -> Void)? = nil) {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                DispatchQueue.main.async { completion?(granted) }
            }
    }

    /// 현재 예산 상태를 평가해, 단계가 올라갔을 때만 알림을 보낸다.
    static func evaluateBudget(_ status: BudgetStatus) {
        guard SettingsStore.shared.notificationsEnabled, status.budget > 0 else { return }

        let defaults = Storage.defaults
        let lastLevel = defaults.integer(forKey: Storage.Key.lastNotifiedLevel)

        // 단계가 낮아지면(새 달 등) 기록 리셋
        if status.level < lastLevel {
            defaults.set(status.level, forKey: Storage.Key.lastNotifiedLevel)
            return
        }
        guard status.level > lastLevel else { return }

        let content = UNMutableNotificationContent()
        content.sound = .default
        switch status.level {
        case 2:
            content.title = "이번 달 예산을 초과했어요"
            content.body  = "지출 \(status.spent.won) / 예산 \(status.budget.won) · \(status.percent)%"
        case 1:
            content.title = "예산의 80%를 사용했어요"
            content.body  = "남은 예산 \(max(status.remaining, 0).won) · 지출 속도를 확인해 보세요"
        default:
            return
        }

        let request = UNNotificationRequest(
            identifier: "budget.level.\(status.level)",
            content: content,
            trigger: nil)   // 즉시 전달
        UNUserNotificationCenter.current().add(request)

        defaults.set(status.level, forKey: Storage.Key.lastNotifiedLevel)
    }
}
