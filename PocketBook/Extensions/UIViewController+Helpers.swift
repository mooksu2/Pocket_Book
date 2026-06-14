// Extensions/UIViewController+Helpers.swift
import UIKit

// MARK: - 지출 삭제 + 되돌리기 (기록·캘린더 탭 공용 · 단일 진실 공급원)
extension UIViewController {

    /// 지출 스와이프 삭제 + 되돌리기 토스트.
    /// - 자동 생성분(recurringID != nil): skipMonth(재생성 방지) / Undo → unskip
    /// - 일반 지출: 영구 삭제 / Undo → 동일 id 복원
    /// 연속 삭제는 UndoCenter가 모아 하나의 토스트로 처리한다.
    func deleteExpenseWithUndo(_ expense: Expense, in host: UIView? = nil) {
        Haptic.medium()
        let snapshot = Expense(
            id: expense.id, category: expense.category, amount: expense.amount,
            memo: expense.memo, date: expense.date, tags: expense.tags,
            isFixed: expense.isFixed, recurringID: expense.recurringID)

        ExpenseStore.shared.delete(id: expense.id)   // recurringID 있으면 내부 skipMonth

        let label = expense.recurringID != nil ? "이번 달 건너뛰었어요" : "지출이 삭제됐어요"
        UndoCenter.push(label: label, in: host ?? view) {
            Haptic.success()
            ExpenseStore.shared.add(snapshot)        // recurringID 있으면 내부 unskip
        }
    }

    /// 지출 행 스와이프 구성 — 자동 생성분은 오렌지 '건너뛰기', 일반은 빨강 '삭제'.
    func expenseSwipeConfig(_ expense: Expense, in host: UIView? = nil) -> UISwipeActionsConfiguration {
        let isAuto = expense.recurringID != nil
        let action = UIContextualAction(style: .destructive, title: nil) { [weak self] _, _, done in
            self?.deleteExpenseWithUndo(expense, in: host)
            done(true)
        }
        action.image = UIImage(systemName: isAuto ? "calendar.badge.minus" : "trash.fill")
        action.backgroundColor = isAuto ? .systemOrange : .systemRed
        return UISwipeActionsConfiguration(actions: [action])
    }

    /// 이미 모달이 떠 있으면 무시 — 버튼/셀 연타로 인한 중복 present 방지.
    func presentOnce(_ vc: UIViewController, animated: Bool = true) {
        guard presentedViewController == nil, view.window != nil else { return }
        present(vc, animated: animated)
    }
}

// MARK: - 되돌리기 누적 처리 (연타 삭제 시 이전 Undo 소실 방지)
/// 짧은 시간 내 연속 삭제를 모아 하나의 토스트로 일괄 되돌리기.
/// (단일 삭제 UX는 그대로 — 1건이면 원래 문구를 그대로 보여준다)
enum UndoCenter {
    private static var pending: [() -> Void] = []
    private static var expire: DispatchWorkItem?
    private static let window: TimeInterval = 3.0

    static func push(label: String, in host: UIView?, _ undo: @escaping () -> Void) {
        pending.append(undo)
        let count = pending.count
        let message = count == 1 ? label : "\(count)건 처리됐어요"

        Toast.showWithAction(message, actionTitle: "되돌리기", in: host, duration: window) {
            let all = pending
            pending.removeAll()
            expire?.cancel(); expire = nil
            all.reversed().forEach { $0() }   // LIFO 복원
        }

        // 토스트 만료 시 확정 (되돌릴 수 없음)
        expire?.cancel()
        let w = DispatchWorkItem { pending.removeAll(); expire = nil }
        expire = w
        DispatchQueue.main.asyncAfter(deadline: .now() + window, execute: w)
    }
}
