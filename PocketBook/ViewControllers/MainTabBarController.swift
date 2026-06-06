// ViewControllers/MainTabBarController.swift
import UIKit

final class MainTabBarController: UITabBarController {
    override func viewDidLoad() {
        super.viewDidLoad()

        let list = UINavigationController(rootViewController: ListViewController())
        let calendar = UINavigationController(rootViewController: CalendarViewController())
        let stats = UINavigationController(rootViewController: StatsViewController())
        let settings = UINavigationController(rootViewController: SettingsViewController())
        list.navigationBar.prefersLargeTitles = false
        calendar.navigationBar.prefersLargeTitles = false
        stats.navigationBar.prefersLargeTitles = false
        settings.navigationBar.prefersLargeTitles = false

        list.tabBarItem  = UITabBarItem(title: "기록",
            image: UIImage(systemName: "list.bullet"),
            selectedImage: UIImage(systemName: "list.bullet"))
        calendar.tabBarItem = UITabBarItem(title: "캘린더",
            image: UIImage(systemName: "calendar"),
            selectedImage: UIImage(systemName: "calendar"))
        stats.tabBarItem = UITabBarItem(title: "통계",
            image: UIImage(systemName: "chart.pie"),
            selectedImage: UIImage(systemName: "chart.pie.fill"))
        settings.tabBarItem = UITabBarItem(title: "설정",
            image: UIImage(systemName: "gearshape"),
            selectedImage: UIImage(systemName: "gearshape.fill"))

        viewControllers = [list, calendar, stats, settings]

        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        tabBar.standardAppearance = appearance
        tabBar.tintColor = Theme.Color.point
    }
}
