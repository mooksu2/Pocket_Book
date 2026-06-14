// ViewControllers/CardFormViewController.swift
import UIKit

/// 카드형 입력 폼 공통 골격 — scroll + 하단 저장 버튼 + 카드/행 빌더 + 키보드 회피.
/// AddViewController·RecurringEditViewController가 상속해 폼 본문(makeFormStack)과
/// 저장 로직(didTapSave)만 채운다.
class CardFormViewController: UIViewController, UIGestureRecognizerDelegate, UITextFieldDelegate {

    /// 키보드·저장 버튼에 폼이 가려지지 않도록 전체를 스크롤로 감싼다
    let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.keyboardDismissMode = .interactive
        sv.showsVerticalScrollIndicator = false
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()
    let saveButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("저장하기", for: .normal)
        b.titleLabel?.font = Theme.Font.title(17)
        b.setTitleColor(.white, for: .normal)
        b.backgroundColor = Theme.Color.point
        b.layer.cornerRadius = 14
        b.layer.cornerCurve = .continuous
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    /// 빈 곳 탭으로 키패드 내릴 때 무시할 입력 뷰 (금액 라벨/키패드 토글 충돌 방지) — 서브클래스가 설정
    var protectedTapView: UIView?

    /// 서브클래스가 폼 본문 스택을 조립해 돌려준다
    func makeFormStack() -> UIStackView { UIStackView() }
    /// 저장 버튼 탭
    @objc func didTapSave() {}

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.Color.background

        let stack = makeFormStack()
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(stack)
        view.addSubview(saveButton)
        saveButton.addTarget(self, action: #selector(didTapSave), for: .touchUpInside)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: saveButton.topAnchor, constant: -Theme.Space.sm),

            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: Theme.Space.md),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: Theme.Space.lg),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -Theme.Space.lg),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -Theme.Space.md),
            stack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -2 * Theme.Space.lg),

            saveButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Theme.Space.lg),
            saveButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Theme.Space.lg),
            saveButton.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor, constant: -Theme.Space.md),
            saveButton.heightAnchor.constraint(equalToConstant: 54),
        ])

        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        tap.delegate = self
        view.addGestureRecognizer(tap)
    }

    @objc func dismissKeyboard() { view.endEditing(true) }

    // MARK: - 공용 빌더
    /// 흰 카드 (그림자·shadowPath 최적화 + layoutMargins)
    func card(padding: UIEdgeInsets = UIEdgeInsets(top: Theme.Space.lg, left: Theme.Space.lg,
                                                   bottom: Theme.Space.lg, right: Theme.Space.lg)) -> UIView {
        let v = CardView()
        v.layoutMargins = padding
        return v
    }
    /// 카드 안에 콘텐츠를 layoutMargins 기준으로 채운다
    func embed(_ content: UIView, in card: UIView) {
        content.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(content)
        let m = card.layoutMarginsGuide
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: m.topAnchor),
            content.leadingAnchor.constraint(equalTo: m.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: m.trailingAnchor),
            content.bottomAnchor.constraint(equalTo: m.bottomAnchor),
        ])
    }
    /// 좌측 라벨 + 우측 값 형태의 옵션 행
    func optionRow(_ title: String, _ control: UIView) -> UIView {
        let label = UILabel()
        label.text = title
        label.font = Theme.Font.title(15)   // 볼드
        label.textColor = Theme.Color.mainText
        label.translatesAutoresizingMaskIntoConstraints = false
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        control.translatesAutoresizingMaskIntoConstraints = false
        control.setContentHuggingPriority(.required, for: .horizontal)
        let spacer = UIView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let row = UIStackView(arrangedSubviews: [label, spacer, control])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = Theme.Space.md
        return row
    }
    func hairline() -> UIView {
        let v = UIView()
        v.backgroundColor = Theme.Color.hairline
        v.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return v
    }
    func makeFieldLabel(_ t: String) -> UILabel {
        let l = UILabel(); l.text = t
        l.font = Theme.Font.title(15); l.textColor = Theme.Color.mainText   // 볼드
        return l
    }

    // MARK: - Gesture / TextField (공용)
    func gestureRecognizer(_ g: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard let v = touch.view else { return true }
        // 금액 라벨·버튼·스위치·텍스트필드 위 탭은 무시 (키패드 토글 충돌 방지)
        if let p = protectedTapView, v.isDescendant(of: p) { return false }
        if v is UIControl || v is UITextField { return false }
        return true
    }

    func textFieldShouldReturn(_ tf: UITextField) -> Bool { tf.resignFirstResponder(); return true }
    /// 키보드가 올라온 뒤 포커스 필드를 스크롤로 끌어올린다 (저장 버튼에 가려짐 방지)
    func textFieldDidBeginEditing(_ tf: UITextField) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.view.layoutIfNeeded()
            let rect = tf.convert(tf.bounds, to: self.scrollView).insetBy(dx: 0, dy: -Theme.Space.lg)
            self.scrollView.scrollRectToVisible(rect, animated: true)
        }
    }
}
