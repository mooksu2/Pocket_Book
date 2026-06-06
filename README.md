# PocketBook 💸

빠르게 기록하는 일상 가계부 — iOS · Swift · UIKit

> 카테고리 선택 → 금액 입력 → 저장. 하루 평균 30초 안에 끝나는 지출 기록.

---

## 핵심 가치

기록의 **마찰을 줄이는 것** 하나에 집중합니다. 앱을 켜고 `+` → 카테고리 칩 한 번 탭 → 금액 입력 → 저장이면 끝입니다.

## 구현 범위 (계획서 대비)

| 우선순위 | 기능 | 상태 |
|---|---|---|
| **P0** | 지출 입력·저장 | ✅ |
| **P0** | 지출 리스트 조회 (날짜별 그룹·일일 합계) | ✅ |
| **P0** | 월별 합계 (카운트업 애니메이션) | ✅ |
| **P1** | 카테고리별 통계 차트 (도넛 + 막대) | ✅ |
| **P2** | 지출 수정·삭제 (스와이프·확인 다이얼로그) | ✅ |
| **P3** | **예산 설정·초과 알림** (`UNUserNotificationCenter`) | ✅ |
| **P3** | **iCloud 동기화** (`NSUbiquitousKeyValueStore`) | ✅ |
| 확장 | 다크 모드 | ✅ |

## 아키텍처 — 3계층

```
Presentation   ViewControllers · Views · DesignSystem
     │  (NotificationCenter)
Business Logic ExpenseStore · SettingsStore · Services
     │  (Codable + JSONEncoder)
Persistence    UserDefaults  ·  NSUbiquitousKeyValueStore (iCloud)
```

- **모델**: `Expense`(struct) + `Category`(enum), 둘 다 `Codable`.
- **저장**: `ExpenseStore`가 배열을 `JSONEncoder`로 인코딩 → `UserDefaults`에 저장, 앱 시작 시 `JSONDecoder`로 복원. 디코딩 실패 시 빈 배열로 폴백.
- **변경 통보**: `NotificationCenter`로 화면 자동 갱신.
- **외부 라이브러리 의존성 0** — 차트는 전부 Core Graphics / Core Animation으로 직접 구현.

## 화면

- **기록 탭** — 이번 달 총액(카운트업) · 예산 진행바 · "가장 많이 쓴 카테고리 + 하루 평균" 인사이트 · 날짜별 섹션 리스트 · 플로팅 `+` 버튼.
- **입력 모달** — 카테고리 칩 4개 · 큰 금액 표시 · 빠른 금액 버튼(+1천/5천/1만/5만) · 실시간 콤마 포맷 · 메모 · 날짜.
- **통계 탭** — 도넛/막대 토글 차트(애니메이션) · 카테고리별 내역 리스트.
- **설정 탭** — 월 예산 · iCloud 동기화 · 예산 초과 알림.

## 빌드 방법

1. **Xcode 12.5 이상**으로 `PocketBook.xcodeproj` 열기 (Deployment Target iOS 14.0, 프로젝트 포맷 objectVersion 50).
2. 시뮬레이터 선택 후 ⌘R — 데모 데이터가 채워진 상태로 바로 실행됩니다. 별도 설정/권한 세팅 없이 즉시 빌드됩니다.

> **iCloud 동기화**를 실제로 기기 간 동작시키려면 앱 타깃 **Signing & Capabilities** 에서 **iCloud → Key-value storage** capability만 추가하면 됩니다. 미설정 시 코드는 안전하게 로컬 저장으로 폴백하므로 앱은 그대로 정상 동작합니다. (예산·알림은 추가 설정 없이 바로 사용 가능)

## 예외 처리

- 금액 0원 → 저장 버튼 비활성화
- 음수 → 숫자 키패드로 원천 차단
- 9자리 초과 → 입력 무시
- 삭제 → 확인 다이얼로그
- 저장 데이터 손상 → 빈 배열 폴백 (강제 종료 방지)

## 기술 스택

`Swift 5` · `UIKit` · `Core Graphics` · `Core Animation` · `Codable` + `UserDefaults` · `NSUbiquitousKeyValueStore` · `UNUserNotificationCenter` · `NotificationCenter`
