// Views/CalendarDayCell.swift
import UIKit

/// 달력의 한 칸. 날짜 숫자 + (지출 있는 날) 일별 합계 금액 표시. 선택/오늘 상태 지원.
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
    /// 일별 지출 합계 (점 대신 정보를 직접 보여준다)
    private let amountLabel: UILabel = {
        let l = UILabel()
        l.font = Theme.Font.money(9, .semibold)
        l.textColor = Theme.Color.tertiaryText
        l.textAlignment = .center
        l.adjustsFontSizeToFitWidth = true
        l.minimumScaleFactor = 0.8
        l.isUserInteractionEnabled = false
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(circle)
        addSubview(dayLabel)
        addSubview(amountLabel)
        NSLayoutConstraint.activate([
            circle.centerXAnchor.constraint(equalTo: centerXAnchor),
            circle.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -5),
            circle.widthAnchor.constraint(equalToConstant: 32),
            circle.heightAnchor.constraint(equalToConstant: 32),

            dayLabel.centerXAnchor.constraint(equalTo: circle.centerXAnchor),
            dayLabel.centerYAnchor.constraint(equalTo: circle.centerYAnchor),

            amountLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            amountLabel.topAnchor.constraint(equalTo: circle.bottomAnchor, constant: 1),
            amountLabel.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, constant: -2),
        ])
        circle.layer.cornerRadius = 16
    }
    required init?(coder: NSCoder) { fatalError() }

    /// column: 0 = 일요일 ... 6 = 토요일 (주말 색상용)
    func configure(date: Date?, day: Int?, column: Int,
                   total: Int?,
                   isToday: Bool, isSelected: Bool) {
        self.date = date
        guard let day = day else {            // 빈 칸
            isUserInteractionEnabled = false
            dayLabel.text = nil
            circle.backgroundColor = .clear
            circle.layer.borderWidth = 0
            amountLabel.text = nil
            return
        }
        isUserInteractionEnabled = true
        dayLabel.text = "\(day)"
        amountLabel.text = total.map { $0.compactWon }

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
            amountLabel.textColor = Theme.Color.point   // 선택일은 금액도 포인트색
        } else if isToday {
            circle.backgroundColor = Theme.Color.pointSoft
            circle.layer.borderWidth = 0
            dayLabel.textColor = Theme.Color.point
            amountLabel.textColor = Theme.Color.tertiaryText
        } else {
            circle.backgroundColor = .clear
            circle.layer.borderWidth = 0
            dayLabel.textColor = weekendColor
            amountLabel.textColor = Theme.Color.tertiaryText
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
