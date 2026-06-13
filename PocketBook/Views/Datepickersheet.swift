// ViewControllers/DatePickerSheet.swift
import UIKit

/// 날짜를 고르는 하프 시트 — 휠 데이트피커 + 완료 버튼.
/// compact 인라인 피커의 회색 배경/포커스 충돌 문제를 피하려고 별도 시트로 분리.
final class DatePickerSheet: UIViewController {

    var onPick: ((Date) -> Void)?
    private let picker = UIDatePicker()

    init(date: Date) {
        super.init(nibName: nil, bundle: nil)
        picker.date = date
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.Color.background

        let titleLabel = UILabel()
        titleLabel.text = "날짜 선택"
        titleLabel.font = Theme.Font.title(17)
        titleLabel.textColor = Theme.Color.mainText
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        picker.datePickerMode = .date
        picker.preferredDatePickerStyle = .wheels
        picker.locale = Locale(identifier: "ko_KR")
        picker.translatesAutoresizingMaskIntoConstraints = false
        picker.addTarget(self, action: #selector(changed), for: .valueChanged)

        let done = UIButton(type: .system)
        done.setTitle("완료", for: .normal)
        done.titleLabel?.font = Theme.Font.title(17)
        done.setTitleColor(.white, for: .normal)
        done.backgroundColor = Theme.Color.point
        done.layer.cornerRadius = 14
        done.layer.cornerCurve = .continuous
        done.translatesAutoresizingMaskIntoConstraints = false
        done.addTarget(self, action: #selector(finish), for: .touchUpInside)

        [titleLabel, picker, done].forEach { view.addSubview($0) }
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: Theme.Space.lg),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            picker.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: Theme.Space.sm),
            picker.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            picker.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            done.topAnchor.constraint(greaterThanOrEqualTo: picker.bottomAnchor, constant: Theme.Space.md),
            done.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Theme.Space.lg),
            done.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Theme.Space.lg),
            done.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -Theme.Space.md),
            done.heightAnchor.constraint(equalToConstant: 52),
        ])
    }

    @objc private func changed() { onPick?(picker.date) }
    @objc private func finish() { onPick?(picker.date); dismiss(animated: true) }
}
