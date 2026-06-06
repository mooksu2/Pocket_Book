// AppDelegate.swift
import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // iCloud 동기화 시작 — 설정이 켜져 있으면 원격 변경 감지 (P3)
        CloudSyncService.shared.start()

        // 최초 실행 시 데모 데이터로 화면을 채워 첫인상을 전달
        ExpenseStore.shared.seedDemoDataIfEmpty()

        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = MainTabBarController()
        window?.makeKeyAndVisible()
        return true
    }
}
