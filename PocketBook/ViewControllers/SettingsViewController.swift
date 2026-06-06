// ViewControllers/SettingsViewController.swift
import UIKit

/// 설정 화면 (P3): 월 예산 · iCloud 동기화 · 예산 초과 알림.
final class SettingsViewController: UIViewController {

    private let scroll = UIScrollView()
    private let content = UIStackView()

    // 예산 카드
    private let budgetValueLabel: UILabel = {
        let l = UILabel()
        l.font = Theme.Font.money(28, .heavy)
        l.textColor = Theme.Color.mainText
        return l
    }()
    private let budgetHintLabel: UILabel = {
        let l = UILabel()
        l.font = Theme.Font.caption(13)
        l.textColor = Theme.Color.subText
        l.numberOfLines = 0
        return l
    }()

    private let syncSwitch = UISwitch()
    private let notifySwitch = UISwitch()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.Color.background
        title = "설정"
        buildLayout()
        refresh()
        NotificationCenter.default.addObserver(self, selector: #selector(refresh),
                                               name: .settingsDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(refresh),
                                               name: .expensesDidChange, object: nil)
    }

    // MARK: Layout
    private func buildLayout() {
        scroll.translatesAutoresizingMaskIntoConstraints = false
        content.axis = .vertical
        content.spacing = Theme.Space.xl
        content.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(scroll)
        scroll.addSubview(content)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            content.topAnchor.constraint(equalTo: scroll.topAnchor, constant: Theme.Space.lg),
            content.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Theme.Space.lg),
            content.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Theme.Space.lg),
            content.bottomAnchor.constraint(equalTo: scroll.bottomAnchor, constant: -Theme.Space.xxl),
            content.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -2 * Theme.Space.lg),
        ])

        content.addArrangedSubview(budgetSection())
        content.addArrangedSubview(toggleSection())
        content.addArrangedSubview(footerSection())
    }

    private func sectionTitle(_ t: String) -> UILabel {
        let l = UILabel()
        l.text = t
        l.font = Theme.Font.caption(13)
        l.textColor = Theme.Color.subText
        return l
    }

    private func cardContainer(_ inner: UIView) -> UIView {
        let bg = UIView()
        bg.backgroundColor = Theme.Color.card
        bg.roundCorners(Theme.Radius.md)
        Theme.applyCardShadow(to: bg.layer, opacity: 0.05, radius: 10, y: 4)
        bg.translatesAutoresizingMaskIntoConstraints = false
        inner.translatesAutoresizingMaskIntoConstraints = false
        bg.addSubview(inner)
        NSLayoutConstraint.activate([
            inner.topAnchor.constraint(equalTo: bg.topAnchor, constant: Theme.Space.lg),
            inner.bottomAnchor.constraint(equalTo: bg.bottomAnchor, constant: -Theme.Space.lg),
            inner.leadingAnchor.constraint(equalTo: bg.leadingAnchor, constant: Theme.Space.lg),
            inner.trailingAnchor.constraint(equalTo: bg.trailingAnchor, constant: -Theme.Space.lg),
        ])
        return bg
    }

    // MARK: 예산 섹션
    private func budgetSection() -> UIView {
        let editButton = UIButton(type: .system)
        editButton.setTitle("변경", for: .normal)
        editButton.titleLabel?.font = Theme.Font.title(14)
        editButton.tintColor = Theme.Color.point
        editButton.addTarget(self, action: #selector(editBudget), for: .touchUpInside)

        let topRow = UIStackView(arrangedSubviews: [budgetValueLabel, UIView(), editButton])
        topRow.alignment = .firstBaseline

        let inner = UIStackView(arrangedSubviews: [topRow, budgetHintLabel])
        inner.axis = .vertical
        inner.spacing = 6

        let section = UIStackView(arrangedSubviews: [sectionTitle("월 예산"), cardContainer(inner)])
        section.axis = .vertical
        section.spacing = Theme.Space.sm
        return section
    }

    // MARK: 토글 섹션
    private func toggleSection() -> UIView {
        syncSwitch.onTintColor = Theme.Color.point
        notifySwitch.onTintColor = Theme.Color.point
        syncSwitch.addTarget(self, action: #selector(toggleSync), for: .valueChanged)
        notifySwitch.addTarget(self, action: #selector(toggleNotify), for: .valueChanged)

        let syncRow = toggleRow(
            icon: "icloud", iconColor: Theme.Color.point,
            title: "iCloud 동기화",
            subtitle: "여러 기기에서 같은 가계부를 사용",
            control: syncSwitch)
        let divider = UIView()
        divider.backgroundColor = Theme.Color.hairline
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.heightAnchor.constraint(equalToConstant: 1).isActive = true

        let notifyRow = toggleRow(
            icon: "bell.badge", iconColor: .systemOrange,
            title: "예산 초과 알림",
            subtitle: "80% · 100% 도달 시 알림",
            control: notifySwitch)

        let inner = UIStackView(arrangedSubviews: [syncRow, divider, notifyRow])
        inner.axis = .vertical
        inner.spacing = Theme.Space.md

        let section = UIStackView(arrangedSubviews: [sectionTitle("동기화 · 알림"), cardContainer(inner)])
        section.axis = .vertical
        section.spacing = Theme.Space.sm
        return section
    }

    private func toggleRow(icon: String, iconColor: UIColor,
                           title: String, subtitle: String, control: UIView) -> UIView {
        let iconView = UIImageView(image: UIImage(systemName: icon))
        iconView.tintColor = iconColor
        iconView.contentMode = .scaleAspectFit
        iconView.preferredSymbolConfiguration = .init(pointSize: 18, weight: .semibold)
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: 26).isActive = true

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = Theme.Font.title(15)
        titleLabel.textColor = Theme.Color.mainText

        let subLabel = UILabel()
        subLabel.text = subtitle
        subLabel.font = Theme.Font.caption(12)
        subLabel.textColor = Theme.Color.subText

        let textStack = UIStackView(arrangedSubviews: [titleLabel, subLabel])
        textStack.axis = .vertical
        textStack.spacing = 1

        control.setContentHuggingPriority(.required, for: .horizontal)
        let row = UIStackView(arrangedSubviews: [iconView, textStack, UIView(), control])
        row.axis = .horizontal
        row.spacing = Theme.Space.md
        row.alignment = .center
        return row
    }

    // MARK: 푸터
    private func footerSection() -> UIView {
        let label = UILabel()
        label.text = "PocketBook v1.0\n빠르게 기록하는 일상 가계부"
        label.font = Theme.Font.caption(12)
        label.textColor = Theme.Color.tertiaryText
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }

    // MARK: Actions
    @objc private func refresh() {
        let budget = SettingsStore.shared.monthlyBudget
        if budget > 0 {
            budgetValueLabel.text = budget.won
            budgetValueLabel.textColor = Theme.Color.mainText
            let spent = ExpenseStore.shared.totalAmount(year: Date().year, month: Date().month)
            budgetHintLabel.text = "이번 달 지출 \(spent.won) · 남은 예산 \((budget - spent).won)"
        } else {
            budgetValueLabel.text = "예산 미설정"
            budgetValueLabel.textColor = Theme.Color.tertiaryText
            budgetHintLabel.text = "월 예산을 정하면 메인 화면에 진행률이 표시되고, 초과 시 알림을 받을 수 있어요."
        }
        syncSwitch.isOn = SettingsStore.shared.iCloudSyncEnabled
        notifySwitch.isOn = SettingsStore.shared.notificationsEnabled
    }

    @objc private func editBudget() {
        Haptic.light()
        let alert = UIAlertController(title: "월 예산 설정",
                                      message: "이번 달부터 적용할 예산을 입력하세요.",
                                      preferredStyle: .alert)
        alert.addTextField { tf in
            tf.keyboardType = .numberPad
            tf.placeholder = "예: 500000"
            let current = SettingsStore.shared.monthlyBudget
            if current > 0 { tf.text = "\(current)" }
        }
        alert.addAction(UIAlertAction(title: "예산 없음", style: .destructive) { [weak self] _ in
            SettingsStore.shared.monthlyBudget = 0
            self?.refresh()
        })
        alert.addAction(UIAlertAction(title: "취소", style: .cancel))
        alert.addAction(UIAlertAction(title: "저장", style: .default) { [weak self, weak alert] _ in
            let raw = alert?.textFields?.first?.text ?? ""
            let digits = raw.filter(\.isNumber)
            SettingsStore.shared.monthlyBudget = Int(digits.prefix(9)) ?? 0
            Haptic.success()
            self?.refresh()
        })
        present(alert, animated: true)
    }

    @objc private func toggleSync(_ sw: UISwitch) {
        Haptic.selection()
        SettingsStore.shared.iCloudSyncEnabled = sw.isOn
        if sw.isOn {
            CloudSyncService.shared.start()
            CloudSyncService.shared.pullIfAvailable()
            ExpenseStore.shared.reloadFromDisk()
        }
    }

    @objc private func toggleNotify(_ sw: UISwitch) {
        Haptic.selection()
        if sw.isOn {
            NotificationService.requestAuthorization { [weak self] granted in
                SettingsStore.shared.notificationsEnabled = granted
                if !granted {
                    sw.setOn(false, animated: true)
                    self?.showNotifDeniedAlert()
                }
            }
        } else {
            SettingsStore.shared.notificationsEnabled = false
        }
    }

    private func showNotifDeniedAlert() {
        let a = UIAlertController(title: "알림 권한이 필요해요",
                                  message: "설정 > 알림에서 PocketBook 알림을 켜주세요.",
                                  preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "확인", style: .default))
        present(a, animated: true)
    }
}
