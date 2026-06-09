// AppDelegate.swift
import UIKit
import UserNotifications
import SwiftData

@main
class AppDelegate: UIResponder, UIApplicationDelegate,
                   UNUserNotificationCenterDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // ModelContainer 초기화
        _ = PocketBookContainer.shared

        // 포그라운드에서도 알림 배너 표시
        UNUserNotificationCenter.current().delegate = self

        window = UIWindow(frame: UIScreen.main.bounds)
        window?.backgroundColor = .white

        let splash = SplashViewController()
        splash.onComplete = { [weak self] in
            guard let w = self?.window else { return }
            UIView.transition(with: w, duration: 0.3, options: .transitionCrossDissolve) {
                w.rootViewController = MainTabBarController()
            }
        }
        window?.rootViewController = splash
        window?.makeKeyAndVisible()
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        let result = RecurringStore.shared.materializeDueExpenses()
        guard !result.isEmpty else { return }

        let message: String
        if result.count == 1, let name = result.firstName {
            message = "고정지출 '\(name)'이(가) 기록됐어요"
        } else if let name = result.firstName {
            message = "고정지출 '\(name)' 외 \(result.count - 1)건이 기록됐어요"
        } else {
            message = "고정지출 \(result.count)건이 기록됐어요"
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            Toast.show(message, style: Toast.Style.info, duration: 2.2)
        }
    }
}
