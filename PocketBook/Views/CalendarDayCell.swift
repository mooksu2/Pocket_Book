// Views/CalendarDayCell.swift
import UIKit

/// 달력의 한 칸. 날짜 숫자 + (지출 있는 날) 점 표시. 선택/오늘 상태 지원.
final class CalendarDayCell: UIControl {

    private(set) var date: Date?

    private let circle: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.isUserInteractionEnabled = false
        return v
    }()
    private let dayLabel: UILabel = {
        let l = UILabel()
        l.font = Theme.Font.money(15, .medium)
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    private let dot: UIView = {
        let v = UIView()
        v.layer.cornerRadius = 3
        v.translatesAutoresizingMaskIntoConstraints = false
        v.isUserInteractionEnabled = false
        return v
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(circle)
        addSubview(dayLabel)
        addSubview(dot)
        NSLayoutConstraint.activate([
            circle.centerXAnchor.constraint(equalTo: centerXAnchor),
            circle.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -3),
            circle.widthAnchor.constraint(equalToConstant: 32),
            circle.heightAnchor.constraint(equalToConstant: 32),

            dayLabel.centerXAnchor.constraint(equalTo: circle.centerXAnchor),
            dayLabel.centerYAnchor.constraint(equalTo: circle.centerYAnchor),

            dot.centerXAnchor.constraint(equalTo: centerXAnchor),
            dot.topAnchor.constraint(equalTo: circle.bottomAnchor, constant: 1),
            dot.widthAnchor.constraint(equalToConstant: 6),
            dot.heightAnchor.constraint(equalToConstant: 6),
        ])
        circle.layer.cornerRadius = 16
    }
    required init?(coder: NSCoder) { fatalError() }

    /// column: 0 = 일요일 ... 6 = 토요일 (주말 색상용)
    func configure(date: Date?, day: Int?, column: Int,
                   hasExpense: Bool, dotColor: UIColor,
                   isToday: Bool, isSelected: Bool) {
        self.date = date
        guard let day = day else {            // 빈 칸
            isUserInteractionEnabled = false
            dayLabel.text = nil
            circle.backgroundColor = .clear
            circle.layer.borderWidth = 0
            dot.isHidden = true
            return
        }
        isUserInteractionEnabled = true
        dayLabel.text = "\(day)"

        // 기본 색 (주말 구분)
        let weekendColor: UIColor
        switch column {
        case 0:  weekendColor = .systemRed
        case 6:  weekendColor = Theme.Color.point
        default: weekendColor = Theme.Color.mainText
        }

        if isSelected {
            circle.backgroundColor = Theme.Color.point
            circle.layer.borderWidth = 0
            dayLabel.textColor = .white
            dot.isHidden = true
        } else if isToday {
            circle.backgroundColor = Theme.Color.pointSoft
            circle.layer.borderWidth = 0
            dayLabel.textColor = Theme.Color.point
            dot.isHidden = !hasExpense
            dot.backgroundColor = dotColor
        } else {
            circle.backgroundColor = .clear
            circle.layer.borderWidth = 0
            dayLabel.textColor = weekendColor
            dot.isHidden = !hasExpense
            dot.backgroundColor = dotColor
        }
    }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.08) {
                self.transform = self.isHighlighted && self.isUserInteractionEnabled
                    ? CGAffineTransform(scaleX: 0.92, y: 0.92) : .identity
            }
        }
    }
}
