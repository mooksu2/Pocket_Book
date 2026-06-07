// AppDelegate.swift
import UIKit
import UserNotifications

@main
class AppDelegate: UIResponder, UIApplicationDelegate,
                   UNUserNotificationCenterDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // 포그라운드에서도 알림 배너 표시
        UNUserNotificationCenter.current().delegate = self

        CloudSyncService.shared.start()
        ExpenseStore.shared.seedDemoDataIfEmpty()

        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = MainTabBarController()
        window?.makeKeyAndVisible()
        return true
    }

    // 앱이 열려 있을 때도 배너 + 소리 표시
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
