// Views/Toast.swift
import UIKit

/// 앱 전역에서 재사용하는 토스트. 성공/안내 두 스타일 지원.
/// 어느 뷰 컨트롤러에서든 Toast.show(...)로 호출.
enum Toast {

    enum Style {
        case success   // 초록 체크 — 저장/완료 피드백
        case info      // 파란 정보 — 안내성 메시지

        var symbol: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .info:    return "sparkles"
            }
        }
        var tint: UIColor {
            switch self {
            case .success: return .systemGreen
            case .info:    return Theme.Color.point
            }
        }
    }

    /// 토스트 표시. host가 nil이면 최상단 윈도우에 자동으로 띄움.
    static func show(_ message: String,
                     style: Style = .success,
                     in host: UIView? = nil,
                     duration: TimeInterval = 1.8) {
        guard let target = host ?? topWindow() else { return }

        let container = UIView()
        container.backgroundColor = UIColor.label.withAlphaComponent(0.92)
        container.roundCorners(Theme.Radius.pill)
        container.translatesAutoresizingMaskIntoConstraints = false

        let icon = UIImageView(image: UIImage(systemName: style.symbol))
        icon.tintColor = style.tint
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text = message
        label.font = Theme.Font.title(14)
        label.textColor = .systemBackground
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(icon)
        container.addSubview(label)
        target.addSubview(container)

        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            icon.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 18),
            icon.heightAnchor.constraint(equalToConstant: 18),
            label.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10),
            container.centerXAnchor.constraint(equalTo: target.centerXAnchor),
            container.leadingAnchor.constraint(greaterThanOrEqualTo: target.leadingAnchor, constant: 24),
            container.trailingAnchor.constraint(lessThanOrEqualTo: target.trailingAnchor, constant: -24),
            container.bottomAnchor.constraint(equalTo: target.safeAreaLayoutGuide.bottomAnchor, constant: -90),
        ])

        container.alpha = 0
        container.transform = CGAffineTransform(translationX: 0, y: 10)
        UIView.animate(withDuration: 0.3) {
            container.alpha = 1
            container.transform = .identity
        }
        UIView.animate(withDuration: 0.3, delay: duration) {
            container.alpha = 0
        } completion: { _ in container.removeFromSuperview() }
    }

    /// 현재 화면에 보이는 최상단 윈도우
    private static func topWindow() -> UIView? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }

    /// 되돌리기 버튼이 달린 토스트 (삭제 Undo 등)
    /// - Parameters:
    ///   - actionTitle: 버튼 텍스트 (예: "되돌리기")
    ///   - onAction: 버튼 탭 시 실행
    static func showWithAction(_ message: String,
                               actionTitle: String,
                               in host: UIView? = nil,
                               duration: TimeInterval = 3.0,
                               onAction: @escaping () -> Void) {
        guard let target = host ?? topWindow() else { return }

        let container = UIView()
        container.backgroundColor = UIColor.label.withAlphaComponent(0.92)
        container.roundCorners(Theme.Radius.pill)
        container.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text = message
        label.font = Theme.Font.title(14)
        label.textColor = .systemBackground
        label.translatesAutoresizingMaskIntoConstraints = false

        let button = UIButton(type: .system)
        button.setTitle(actionTitle, for: .normal)
        button.titleLabel?.font = Theme.Font.title(14)
        button.setTitleColor(Theme.Color.point, for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setContentHuggingPriority(.required, for: .horizontal)

        let divider = UIView()
        divider.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.25)
        divider.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(label)
        container.addSubview(divider)
        container.addSubview(button)
        target.addSubview(container)

        var dismissed = false
        let dismiss = {
            guard !dismissed else { return }
            dismissed = true
            UIView.animate(withDuration: 0.25, animations: {
                container.alpha = 0
            }, completion: { _ in
                container.removeFromSuperview()
            })
        }

        button.addAction(UIAction { _ in
            onAction()
            dismiss()
        }, for: .touchUpInside)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 18),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 11),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -11),
            divider.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 14),
            divider.widthAnchor.constraint(equalToConstant: 1),
            divider.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            divider.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8),
            button.leadingAnchor.constraint(equalTo: divider.trailingAnchor, constant: 14),
            button.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -18),
            button.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            container.centerXAnchor.constraint(equalTo: target.centerXAnchor),
            container.leadingAnchor.constraint(greaterThanOrEqualTo: target.leadingAnchor, constant: 24),
            container.trailingAnchor.constraint(lessThanOrEqualTo: target.trailingAnchor, constant: -24),
            container.bottomAnchor.constraint(equalTo: target.safeAreaLayoutGuide.bottomAnchor, constant: -90),
        ])

        container.alpha = 0
        container.transform = CGAffineTransform(translationX: 0, y: 10)
        UIView.animate(withDuration: 0.3) {
            container.alpha = 1
            container.transform = .identity
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { dismiss() }
    }
}
