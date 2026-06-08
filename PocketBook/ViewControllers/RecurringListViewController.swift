import UIKit

/// 고정지출 허브: 이번 달 요약 + 등록된 고정지출 목록. 우상단 +로 등록, 탭 수정, 스와이프 삭제/일시정지.
final class RecurringListViewController: UIViewController {

    private var items: [RecurringExpense] = []

    // MARK: Summary header
    private let summaryCard: UIView = {
        let v = UIView()
        v.backgroundColor = Theme.Color.pointSoft
        v.roundCorners(Theme.Radius.md)
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()
    private let summaryCaption: UILabel = {
        let l = UILabel()
        l.text = "이번 달 고정지출"
        l.font = Theme.Font.caption(12)
        l.textColor = Theme.Color.point
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    private let summaryTotal: UILabel = {
        let l = UILabel()
        l.font = Theme.Font.money(28, .bold)
        l.textColor = Theme.Color.mainText
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    private let progressTrack: UIView = {
        let v = UIView()
        v.backgroundColor = Theme.Color.point.withAlphaComponent(0.18)
        v.roundCorners(4)
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()
    private let progressFill: UIView = {
        let v = UIView()
        v.backgroundColor = Theme.Color.point
        v.roundCorners(4)
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()
    private var progressFillWidth: NSLayoutConstraint!
    private var lastRatio: CGFloat = 0
    private let splitLabel: UILabel = {
        let l = UILabel()
        l.font = Theme.Font.caption(12)
        l.textColor = Theme.Color.subText
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let tableView: UITableView = {
        let t = UITableView(frame: .zero, style: .plain)
        t.separatorStyle = .none
        t.backgroundColor = .clear
        t.rowHeight = 68
        t.translatesAutoresizingMaskIntoConstraints = false
        return t
    }()
    private let emptyLabel: UILabel = {
        let l = UILabel()
        l.text = "아직 등록된 고정지출이 없어요.\n오른쪽 위 + 로 월세·구독 같은\n매달 빠지는 항목을 등록해보세요."
        l.numberOfLines = 0
        l.textAlignment = .center
        l.font = Theme.Font.body(14)
        l.textColor = Theme.Color.tertiaryText
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // MARK: Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.Color.background
        title = "고정지출"
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .add, target: self, action: #selector(openAdd))
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close, target: self, action: #selector(close))
        
        buildLayout()
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(RecurringCell.self, forCellReuseIdentifier: "rec")

        NotificationCenter.default.addObserver(self, selector: #selector(reload),
                                               name: .recurringDidChange, object: nil)
        reload()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        progressFillWidth.constant = progressTrack.bounds.width * lastRatio
    }

    // MARK: Layout
    private func buildLayout() {
        view.addSubview(summaryCard)
        summaryCard.addSubview(summaryCaption)
        summaryCard.addSubview(summaryTotal)
        summaryCard.addSubview(progressTrack)
        progressTrack.addSubview(progressFill)
        summaryCard.addSubview(splitLabel)
        view.addSubview(tableView)
        view.addSubview(emptyLabel)

        progressFillWidth = progressFill.widthAnchor.constraint(equalToConstant: 0)

        NSLayoutConstraint.activate([
            summaryCard.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: Theme.Space.md),
            summaryCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Theme.Space.lg),
            summaryCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Theme.Space.lg),

            summaryCaption.topAnchor.constraint(equalTo: summaryCard.topAnchor, constant: Theme.Space.md),
            summaryCaption.leadingAnchor.constraint(equalTo: summaryCard.leadingAnchor, constant: Theme.Space.lg),

            summaryTotal.topAnchor.constraint(equalTo: summaryCaption.bottomAnchor, constant: 2),
            summaryTotal.leadingAnchor.constraint(equalTo: summaryCard.leadingAnchor, constant: Theme.Space.lg),

            progressTrack.topAnchor.constraint(equalTo: summaryTotal.bottomAnchor, constant: Theme.Space.md),
            progressTrack.leadingAnchor.constraint(equalTo: summaryCard.leadingAnchor, constant: Theme.Space.lg),
            progressTrack.trailingAnchor.constraint(equalTo: summaryCard.trailingAnchor, constant: -Theme.Space.lg),
            progressTrack.heightAnchor.constraint(equalToConstant: 7),

            progressFill.leadingAnchor.constraint(equalTo: progressTrack.leadingAnchor),
            progressFill.topAnchor.constraint(equalTo: progressTrack.topAnchor),
            progressFill.bottomAnchor.constraint(equalTo: progressTrack.bottomAnchor),
            progressFillWidth,

            splitLabel.topAnchor.constraint(equalTo: progressTrack.bottomAnchor, constant: Theme.Space.sm),
            splitLabel.leadingAnchor.constraint(equalTo: summaryCard.leadingAnchor, constant: Theme.Space.lg),
            splitLabel.trailingAnchor.constraint(equalTo: summaryCard.trailingAnchor, constant: -Theme.Space.lg),
            splitLabel.bottomAnchor.constraint(equalTo: summaryCard.bottomAnchor, constant: -Theme.Space.md),

            tableView.topAnchor.constraint(equalTo: summaryCard.bottomAnchor, constant: Theme.Space.md),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyLabel.centerXAnchor.constraint(equalTo: tableView.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: tableView.centerYAnchor, constant: -40),
            emptyLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Theme.Space.xl),
            emptyLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Theme.Space.xl),
        ])
    }

    // MARK: Reload
    @objc private func reload() {
        items = RecurringStore.shared.items.sorted { $0.dayOfMonth < $1.dayOfMonth }
        let total    = RecurringStore.shared.monthlyTotal()
        let recorded = RecurringStore.shared.recordedTotal()
        let pending  = RecurringStore.shared.pendingTotal()

        summaryTotal.text = total.won
        splitLabel.text = "✓ 기록됨 \(recorded.won)   ·   예정 \(pending.won)"

        let ratio = total > 0 ? CGFloat(recorded) / CGFloat(total) : 0
        lastRatio = ratio
        view.layoutIfNeeded()
        progressFillWidth.constant = progressTrack.bounds.width * ratio
        UIView.animate(withDuration: 0.25) { self.view.layoutIfNeeded() }

        emptyLabel.isHidden = !items.isEmpty
        tableView.reloadData()
    }

    // MARK: Actions
    @objc private func openAdd() {
        Haptic.medium()
        presentEditor(for: nil)
    }
    @objc private func close() { dismiss(animated: true) }

    private func presentEditor(for item: RecurringExpense?) {
        let vc = RecurringEditViewController(editing: item)
        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .pageSheet
        present(nav, animated: true)
    }
}

// MARK: - Table
extension RecurringListViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { items.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "rec", for: indexPath) as! RecurringCell
        let item = items[indexPath.row]
        cell.configure(item, recorded: RecurringStore.shared.isRecordedThisMonth(item))
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        presentEditor(for: items[indexPath.row])
    }

    func tableView(_ tableView: UITableView,
                   trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let item = items[indexPath.row]
        let delete = UIContextualAction(style: .destructive, title: "삭제") { [weak self] _, _, done in
            RecurringStore.shared.delete(id: item.id)
            done(true)
        }
        let pauseTitle = item.isActive ? "일시정지" : "재개"
        let pause = UIContextualAction(style: .normal, title: pauseTitle) { _, _, done in
            RecurringStore.shared.setActive(!item.isActive, id: item.id)
            done(true)
        }
        pause.backgroundColor = item.isActive ? UIColor.systemOrange : Theme.Color.point
        return UISwipeActionsConfiguration(actions: [delete, pause])
    }
}

// MARK: - Cell
private final class RecurringCell: UITableViewCell {

    private let iconWrap = UIView()
    private let iconView = UIImageView()
    private let nameLabel = UILabel()
    private let subLabel = UILabel()
    private let amountLabel = UILabel()
    private let statusLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear

        iconWrap.translatesAutoresizingMaskIntoConstraints = false
        iconWrap.layer.cornerRadius = 10
        iconWrap.layer.cornerCurve = .continuous
        iconView.tintColor = .white
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconWrap.addSubview(iconView)

        nameLabel.font = Theme.Font.title(15)
        nameLabel.textColor = Theme.Color.mainText
        subLabel.font = Theme.Font.caption(12)
        subLabel.textColor = Theme.Color.subText
        amountLabel.font = Theme.Font.money(15, .semibold)
        amountLabel.textColor = Theme.Color.mainText
        amountLabel.textAlignment = .right
        statusLabel.font = Theme.Font.caption(11)
        statusLabel.textAlignment = .right

        let textCol = UIStackView(arrangedSubviews: [nameLabel, subLabel])
        textCol.axis = .vertical
        textCol.spacing = 2
        let rightCol = UIStackView(arrangedSubviews: [amountLabel, statusLabel])
        rightCol.axis = .vertical
        rightCol.spacing = 2
        rightCol.alignment = .trailing

        [iconWrap, textCol, rightCol].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }
        textCol.setContentHuggingPriority(.defaultLow, for: .horizontal)

        NSLayoutConstraint.activate([
            iconWrap.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Theme.Space.lg),
            iconWrap.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconWrap.widthAnchor.constraint(equalToConstant: 38),
            iconWrap.heightAnchor.constraint(equalToConstant: 38),
            iconView.centerXAnchor.constraint(equalTo: iconWrap.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconWrap.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20),

            textCol.leadingAnchor.constraint(equalTo: iconWrap.trailingAnchor, constant: Theme.Space.md),
            textCol.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            rightCol.leadingAnchor.constraint(greaterThanOrEqualTo: textCol.trailingAnchor, constant: Theme.Space.sm),
            rightCol.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Theme.Space.lg),
            rightCol.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    func configure(_ item: RecurringExpense, recorded: Bool) {
        iconWrap.backgroundColor = item.category.color
        iconView.image = UIImage(systemName: item.category.symbolName)
        nameLabel.text = item.name.isEmpty ? item.category.rawValue : item.name
        subLabel.text = "매월 \(item.dayOfMonth)일 · \(item.category.rawValue)"
        amountLabel.text = item.amount.won

        if !item.isActive {
            statusLabel.text = "일시정지"
            statusLabel.textColor = Theme.Color.tertiaryText
            contentView.alpha = 0.45
        } else if recorded {
            statusLabel.text = "✓ 기록됨"
            statusLabel.textColor = UIColor.systemGreen
            contentView.alpha = 1
        } else {
            statusLabel.text = "\(item.dayOfMonth)일 예정"
            statusLabel.textColor = Theme.Color.subText
            contentView.alpha = 1
        }
    }
}
