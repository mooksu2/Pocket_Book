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

        RecurringStore.shared.materializeDueExpenses()

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
        RecurringStore.shared.materializeDueExpenses()
    }
}

       
