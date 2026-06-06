// Services/CloudSyncService.swift
import Foundation

/// iCloud 키-값 동기화 (P3: 클라우드 동기화).
/// 계획서 명세대로 NSUbiquitousKeyValueStore를 사용한다.
/// iCloud 미설정 환경에서도 앱이 멈추지 않도록 안전하게 폴백한다.
final class CloudSyncService {

    static let shared = CloudSyncService()
    private init() {}

    private let store = NSUbiquitousKeyValueStore.default
    private var isObserving = false

    func start() {
        guard !isObserving else { return }
        isObserving = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(remoteChanged(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store)
        store.synchronize()

        // 사용 설정이 켜져 있으면 시작 시 원격 → 로컬 끌어오기
        if SettingsStore.shared.iCloudSyncEnabled {
            pullIfAvailable()
        }
    }

    /// 로컬 변경분을 iCloud로 올린다.
    func push(_ encoded: Data) {
        guard SettingsStore.shared.iCloudSyncEnabled else { return }
        store.set(encoded, forKey: Storage.Key.expenses)
        store.synchronize()
    }

    /// iCloud에 데이터가 있으면 로컬로 가져온다. (변경 여부 반환)
    @discardableResult
    func pullIfAvailable() -> Bool {
        guard SettingsStore.shared.iCloudSyncEnabled,
              let data = store.data(forKey: Storage.Key.expenses) else { return false }
        Storage.defaults.set(data, forKey: Storage.Key.expenses)
        return true
    }

    @objc private func remoteChanged(_ note: Notification) {
        guard SettingsStore.shared.iCloudSyncEnabled else { return }
        if pullIfAvailable() {
            // 외부 기기에서 변경됨 → 로컬 스토어 재적재 후 화면 갱신
            ExpenseStore.shared.reloadFromDisk()
        }
    }
}
