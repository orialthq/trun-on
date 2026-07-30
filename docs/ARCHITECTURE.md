# Architecture

## 목표

Android 공유 수신을 먼저 검증하면서, 이후 iOS Share Extension이 같은
도메인 계약을 사용할 수 있도록 플랫폼 입력과 제품 상태를 분리합니다.

```text
Android ACTION_SEND
→ SharedPreferences pending queue
→ Flutter MethodChannel
→ IncomingShareService
→ AppController
→ 공유 확인 / 수집함 / 비교 / 결정
```

## 현재 계층

```text
lib/
├── app/          # 앱 조립과 root state gate
├── core/         # 테마와 포맷터
├── data/         # 플랫폼 서비스와 데모 catalog
├── domain/       # 플랫폼 중립 모델
├── features/     # 화면 단위 UI
└── state/        # 앱 상태와 사용자 액션
```

첫 vertical slice에서는 외부 상태 관리·라우팅·코드 생성 패키지를
사용하지 않습니다. 제품 복잡도가 증가할 때 repository와 view model
경계를 더 세분화합니다.

## Android 공유 계약

채널:

```text
com.orialthq.ori_beauty/incoming_share/v1
```

Dart → Android:

- `drainPendingShares`
- `acknowledgeShares({ ids })`

Android → Dart:

- `pendingSharesChanged`

`pendingSharesChanged`는 데이터를 직접 싣지 않고 다시 drain하라는
신호입니다. cold start에서 Dart handler 준비 전 공유 이벤트가 사라지는
문제를 피하기 위해 Android가 먼저 로컬 queue에 저장합니다.

현재는 `text/plain`만 노출합니다. 이미지 공유는 임시 URI 권한이
사라지기 전에 크기·MIME을 검증하고 앱 전용 저장소로 복사하는 작업이
완성된 뒤 Manifest에 추가합니다.

## iOS 확장 방향

후속 iOS Share Extension은 App Group container에 같은 envelope 형태의
manifest를 기록하고 Runner 앱이 drain하는 구조를 사용합니다. Flutter
UI와 제품 도메인 모델은 유지하고 Swift 확장은 짧은 저장 확인만
담당합니다.

## 안전 경계

- 접근 권한이 없는 SNS 원문이나 영상을 다운로드하지 않는다.
- 공유 텍스트와 URL을 릴리스 로그에 남기지 않는다.
- 제품 매칭이 불확실하면 사용자 확인 상태로 둔다.
- 광고 여부는 명시적 표시만 전달한다.
- 역할 중복을 의학적 안전성 판정처럼 표현하지 않는다.
- 서버가 URL을 가져오는 단계에서는 SSRF와 redirect 제한을 별도 적용한다.
