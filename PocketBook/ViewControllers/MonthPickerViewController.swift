// ViewControllers/MonthPickerViewController.swift
import UIKit

/// 연/월 선택 피커 시트. 탭 → onSelect(year, month) 콜백.
final class MonthPickerViewController: UIViewController {
    var onSelect: ((Int, Int) -> Void)?

    private let baseYear = Calendar.current.component(.year, from: Date())
    private lazy var years = Array((baseYear - 5)...(baseYear + 2))
    private let monthNames = (1...12).map { "\($0)월" }

    private let picker = UIPickerView()
    private var selectedYear: Int
    private var selectedMonth: Int

    init(year: Int, month: Int) {
        self.selectedYear = year
        self.selectedMonth = month
        super.init(nibName: nil, bundle: nil)
        title = "월 선택"
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.Color.background

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "취소", style: .plain, target: self, action: #selector(cancel))
        navigationItem.leftBarButtonItem?.tintColor = Theme.Color.subText

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "선택", style: .done, target: self, action: #selector(confirm))
        navigationItem.rightBarButtonItem?.tintColor = Theme.Color.point

        picker.dataSource = self
        picker.delegate   = self
        picker.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(picker)
        NSLayoutConstraint.activate([
            picker.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -30),
            picker.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            picker.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        if let yi = years.firstIndex(of: selectedYear) {
            picker.selectRow(yi, inComponent: 0, animated: false)
        }
        picker.selectRow(selectedMonth - 1, inComponent: 1, animated: false)
    }

    @objc private func cancel() { dismiss(animated: true) }

    @objc private func confirm() {
        let cb = onSelect
        let y = selectedYear, m = selectedMonth
        dismiss(animated: true) { cb?(y, m) }
    }
}

extension MonthPickerViewController: UIPickerViewDataSource, UIPickerViewDelegate {
    func numberOfComponents(in pickerView: UIPickerView) -> Int { 2 }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        component == 0 ? years.count : monthNames.count
    }
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        component == 0 ? "\(years[row])년" : monthNames[row]
    }
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        if component == 0 { selectedYear  = years[row] }
        else               { selectedMonth = row + 1   }
    }
}
