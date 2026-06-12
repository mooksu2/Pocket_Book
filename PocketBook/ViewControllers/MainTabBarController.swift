// ViewControllers/MainTabBarController.swift
import UIKit

final class MainTabBarController: UITabBarController {

    private lazy var curvedBar = CurvedTabBar(items: [
        .init(title: "기록",   symbol: "list.bullet",       selectedSymbol: "list.bullet"),
        .init(title: "캘린더", symbol: "calendar",          selectedSymbol: "calendar"),
        .init(title: "통계",   symbol: "chart.pie",         selectedSymbol: "chart.pie.fill"),
        .init(title: "설정",   symbol: "gearshape",         selectedSymbol: "gearshape.fill"),
    ])

    /// 커스텀 탭바가 차지하는 안전영역 위 높이 (FAB 등 콘텐츠가 참조)
    static let tabBarContentHeight = CurvedTabBar.barHeight

    override func viewDidLoad() {
        super.viewDidLoad()

        let list = UINavigationController(rootViewController: ListViewController())
        let calendar = UINavigationController(rootViewController: CalendarViewController())
        let stats = UINavigationController(rootViewController: StatsViewController())
        let settings = UINavigationController(rootViewController: SettingsViewController())
        [list, calendar, stats, settings].forEach { $0.navigationBar.prefersLargeTitles = false }
        viewControllers = [list, calendar, stats, settings]

        // 기본 탭바 숨기고 커스텀 탭바로 교체
        tabBar.isHidden = true
        tabBar.isTranslucent = true

        curvedBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(curvedBar)
        NSLayoutConstraint.activate([
            curvedBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            curvedBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            curvedBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            // 콘텐츠 높이 + 홈 인디케이터 영역까지 덮도록 하단까지 채움
            curvedBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor,
                                           constant: -CurvedTabBar.barHeight),
        ])
        curvedBar.onSelect = { [weak self] index in
            self?.selectedIndex = index
        }
        curvedBar.select(0, animated: false, notify: false)
    }

    /// 커스텀 탭바가 콘텐츠를 가리지 않도록, 각 탭 화면에 탭바 높이만큼 하단 safe area를 추가한다.
    /// (safeArea 기준으로 잡힌 모든 레이아웃 — 테이블 인셋·FAB·스크롤뷰 — 이 자동으로 탭바를 회피)
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        for vc in viewControllers ?? [] {
            let inset = CurvedTabBar.barHeight
            if vc.additionalSafeAreaInsets.bottom != inset {
                vc.additionalSafeAreaInsets.bottom = inset
            }
        }
    }
}
