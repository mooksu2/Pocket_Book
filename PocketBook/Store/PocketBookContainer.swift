// Store/PocketBookContainer.swift
import SwiftData

/// 앱 전체에서 공유하는 ModelContainer 싱글톤.
/// CloudKit 동기화는 유료 개발자 계정 활성화 후 cloudKitDatabase: .automatic 으로 변경.
final class PocketBookContainer {

    static let shared = PocketBookContainer()

    let container: ModelContainer

    @MainActor
    var context: ModelContext { container.mainContext }

    private init() {
        let schema = Schema([Expense.self, RecurringExpense.self])
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none   // 유료 계정 활성화 시 .automatic 으로 변경
        )
        do {
            container = try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("ModelContainer 생성 실패: \(error)")
        }
    }
}
