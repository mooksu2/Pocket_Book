// Views/BudgetProgressView.swift
import UIKit

/// 예산 대비 지출 진행바 (P3). 안전/주의/초과 단계에 따라 색이 바뀐다.
final class BudgetProgressView: UIView {

    private let track = UIView()
    private let fill = UIView()
    private let captionLabel: UILabel = {
        let l = UILabel()
        l.font = Theme.Font.caption(12)
        l.textColor = Theme.Color.subText
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    private let remainingLabel: UILabel = {
        let l = UILabel()
        l.font = Theme.Font.money(12, .semibold)
        l.textAlignment = .right
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    private var fillWidth: NSLayoutConstraint!

    override init(frame: CGRect) {
        super.init(frame: frame)
        track.backgroundColor = Theme.Color.hairline
        track.roundCorners(5)
        track.translatesAutoresizingMaskIntoConstraints = false
        fill.roundCorners(5)
        fill.translatesAutoresizingMaskIntoConstraints = false

        track.addSubview(fill)
        addSubview(captionLabel)
        addSubview(remainingLabel)
        addSubview(track)

        fillWidth = fill.widthAnchor.constraint(equalToConstant: 0)
        NSLayoutConstraint.activate([
            captionLabel.topAnchor.constraint(equalTo: topAnchor),
            captionLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            remainingLabel.centerYAnchor.constraint(equalTo: captionLabel.centerYAnchor),
            remainingLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            remainingLabel.leadingAnchor.constraint(greaterThanOrEqualTo: captionLabel.trailingAnchor, constant: 8),

            track.topAnchor.constraint(equalTo: captionLabel.bottomAnchor, constant: 6),
            track.leadingAnchor.constraint(equalTo: leadingAnchor),
            track.trailingAnchor.constraint(equalTo: trailingAnchor),
            track.heightAnchor.constraint(equalToConstant: 10),
            track.bottomAnchor.constraint(equalTo: bottomAnchor),

            fill.leadingAnchor.constraint(equalTo: track.leadingAnchor),
            fill.topAnchor.constraint(equalTo: track.topAnchor),
            fill.bottomAnchor.constraint(equalTo: track.bottomAnchor),
            fillWidth,
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    func configure(_ status: BudgetStatus, animated: Bool) {
        let color: UIColor
        switch status.level {
        case 2:  color = .systemRed
        case 1:  color = .systemOrange
        default: color = Theme.Color.point
        }
        fill.backgroundColor = color
        remainingLabel.textColor = color

        captionLabel.text = "예산 \(status.budget.won) · \(status.percent)%"
        remainingLabel.text = status.isOver
            ? "\(abs(status.remaining).won) 초과"
            : "\(status.remaining.won) 남음"

        layoutIfNeeded()
        let target = track.bounds.width * CGFloat(status.clampedRatio)
        fillWidth.constant = target
        if animated {
            UIView.animate(withDuration: 0.6, delay: 0.1,
                           usingSpringWithDamping: 0.9, initialSpringVelocity: 0.2) {
                self.layoutIfNeeded()
            }
        } else {
            layoutIfNeeded()
        }
    }
}
