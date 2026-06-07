import UIKit

final class SplashViewController: UIViewController {
    var onComplete: (() -> Void)?

    private let logoView: UIImageView = {
        let iv = UIImageView(image: UIImage(named: "SplashLogo"))
        iv.contentMode = .scaleAspectFit
        iv.alpha = 0
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        view.addSubview(logoView)
        NSLayoutConstraint.activate([
            logoView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            logoView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            logoView.widthAnchor.constraint(equalTo: view.widthAnchor),
            logoView.heightAnchor.constraint(equalTo: view.widthAnchor),
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIView.animate(withDuration: 0.45) {
            self.logoView.alpha = 1
        } completion: { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                UIView.animate(withDuration: 0.35) {
                    self.view.alpha = 0
                } completion: { _ in
                    self.onComplete?()
                }
            }
        }
    }
}
