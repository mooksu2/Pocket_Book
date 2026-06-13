// Views/AmountInputView.swift
import UIKit

/// 금액 입력 블록: 큰 ₩ 라벨(탭 → 키패드) + 숨은 숫자 필드 + 빠른 금액 버튼 4개.
/// 지출 입력·고정지출 등록 화면이 공유한다 — 금액 입력 관련 수정은 이 파일 한 곳에서.
final class AmountInputView: UIView {

    // MARK: Public API
    /// 현재 입력된 금액 (원)
    private(set) var amount: Int = 0
    /// 금액이 바뀔 때마다 호출 (저장 버튼 활성화 등)
    var onChanged: ((Int) -> Void)?

    /// 값 주입 (prefill·초기화용) — 라벨과 onChanged까지 동기화
    func setAmount(_ value: Int) {
        amount = min(max(value, 0), Self.maxAmount)
        hiddenField.text = amount > 0 ? "\(amount)" : ""
        refresh()
    }

    /// 숫자 키패드 올리기
    func focus() { hiddenField.becomeFirstResponder() }

    /// 키패드 내리기 + first responder 자격 반납 (모달 닫힘 후 포커스 자동복원 방지)
    func resignFocus() { hiddenField.resignFirstResponder() }

    /// 빈 금액 저장 시도 피드백 — 라벨 좌우 흔들기
    func shake() {
        let anim = CAKeyframeAnimation(keyPath: "transform.translation.x")
        anim.values = [-10, 10, -8, 8, -4, 4, 0]
        anim.duration = 0.4
        amountLabel.layer.add(anim, forKey: "shake")
    }

    // MARK: UI
    private static let maxAmount = 999_999_999

    /// 금액 위 안내 캡션 ("얼마를 쓰셨나요?" 등). 외부에서 설정
    var caption: String? {
        didSet { captionLabel.text = caption; captionLabel.isHidden = (caption == nil) }
    }
    private let captionLabel: UILabel = {
        let l = UILabel()
        l.font = Theme.Font.caption(13)
        l.textColor = Theme.Color.tertiaryText
        l.textAlignment = .center
        l.isHidden = true
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let amountLabel: UILabel = {
        let l = UILabel()
        l.text = "₩0"
        l.font = Theme.Font.money(48, .heavy)
        l.textColor = Theme.Color.subText
        l.textAlignment = .center
        l.adjustsFontSizeToFitWidth = true
        l.minimumScaleFactor = 0.5
        l.isUserInteractionEnabled = true
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    /// 숫자 키패드를 띄우기 위한 숨은 필드
    private let hiddenField: UITextField = {
        let tf = UITextField()
        tf.keyboardType = .numberPad
        tf.isHidden = true
        return tf
    }()
    private let quickRow: UIStackView = {
        let s = UIStackView()
        s.axis = .horizontal
        s.distribution = .fillEqually
        s.spacing = Theme.Space.sm
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    // MARK: Init
    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(hiddenField)
        hiddenField.addTarget(self, action: #selector(typing), for: .editingChanged)

        amountLabel.addGestureRecognizer(
            UITapGestureRecognizer(target: self, action: #selector(labelTapped)))

        [1000, 5000, 10000, 50000].forEach { quickRow.addArrangedSubview(makeQuickButton($0)) }

        let stack = UIStackView(arrangedSubviews: [captionLabel, amountLabel])
        stack.axis = .vertical
        stack.spacing = Theme.Space.md
        stack.setCustomSpacing(Theme.Space.xs, after: captionLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        addSubview(quickRow)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),

            // 퀵버튼 행은 가운데로 모으고 너비를 줄인다 (좌우 꽉 차지 않게)
            quickRow.topAnchor.constraint(equalTo: stack.bottomAnchor, constant: Theme.Space.lg),
            quickRow.centerXAnchor.constraint(equalTo: centerXAnchor),
            quickRow.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.82),
            quickRow.heightAnchor.constraint(equalToConstant: 38),
            quickRow.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: Logic
    @objc private func labelTapped() { focus() }

    @objc private func typing() {
        let digits = (hiddenField.text ?? "").filter(\.isNumber)
        let trimmed = String(digits.prefix(9))           // 9자리 제한
        hiddenField.text = trimmed
        amount = Int(trimmed) ?? 0
        refresh()
    }

    private func bump(_ delta: Int) {
        Haptic.light()
        amount = min(amount + delta, Self.maxAmount)
        hiddenField.text = "\(amount)"
        refresh()
        // 살짝 커졌다 돌아오는 피드백
        amountLabel.transform = CGAffineTransform(scaleX: 1.06, y: 1.06)
        UIView.animate(withDuration: 0.2) { self.amountLabel.transform = .identity }
    }

    private func refresh() {
        amountLabel.text = amount.won
        amountLabel.textColor = amount > 0 ? Theme.Color.mainText : Theme.Color.subText
        onChanged?(amount)
    }

    private func makeQuickButton(_ amount: Int) -> UIButton {
        let b = UIButton(type: .system)
        b.setTitle("+\(Self.shortLabel(amount))", for: .normal)
        b.titleLabel?.font = Theme.Font.title(14)   // 볼드
        b.setTitleColor(Theme.Color.point, for: .normal)
        b.backgroundColor = Theme.Color.pointSoft   // 파란 틴트 = 액션 (회색 필 = 입력 필드)
        b.layer.cornerRadius = 9
        b.layer.cornerCurve = .continuous
        b.addAction(UIAction { [weak self] _ in self?.bump(amount) }, for: .touchUpInside)
        return b
    }
    /// 1000→"1천", 5000→"5천", 10000→"1만", 50000→"5만"
    private static func shortLabel(_ amount: Int) -> String {
        if amount >= 10000 { return "\(amount / 10000)만" }
        return "\(amount / 1000)천"
    }
}
