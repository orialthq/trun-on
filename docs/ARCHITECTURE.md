# Architecture

## 1. 목표

플랫폼에서 받은 원본, 분석기가 만든 파생 결과, 사용자가 확인한 값,
제품별 정리 결과를 서로 분리합니다.

```text
Android Share / App Paste
→ Durable Raw Capture
→ Material Preparation
→ Structured Analysis
→ Review & Correction
→ Product Resolution
→ Content / Product Views
```

핵심 설계 원칙은 다음과 같습니다.

- 수신 성공과 분석 성공을 분리합니다.
- 원본은 immutable하게 보존합니다.
- 파생 결과에는 원본 근거와 분석 버전을 남깁니다.
- 사용자 수정은 원본을 덮어쓰지 않습니다.
- 제품 언급과 확인된 제품을 분리합니다.
- 잘못된 자동 병합보다 미병합을 허용합니다.
- 활용·비교·구매 결정 도메인은 현재 구조에 포함하지 않습니다.

### 현재 구현 수준

현재 pre-alpha는 Android `text/plain`과 단일 JPEG·PNG·WebP 공유를
native pending queue에 먼저 기록합니다. 이미지는 MIME signature,
크기·해상도를 검증해 앱 전용 임시 경로에 복사하고, Dart가 보존 경로로
다시 옮긴 뒤 원본·분석·검토 상태를 versioned JSON snapshot으로
`SharedPreferences`에 동기 commit합니다. commit 성공 뒤에만 pending
입력을 acknowledge합니다. Android Auto Backup은 비활성화합니다.

텍스트는 deterministic rule을 사용하고, 이미지는 로컬 중계 서버가
`gpt-5.6-luna`의 strict Structured Outputs로 비동기 분석합니다. 완료된
분석 결과를 snapshot에 함께 저장하므로 재시작만으로 같은 이미지를 다시
과금하지 않습니다. `semanticFingerprint`는 계산·저장하지만 서로 다른
transport event의 중복 판정에는 아직 사용하지 않습니다. 사용자 삭제,
다중 이미지 분석, 로컬 DB·append-only correction은 다음 구현 목표입니다.

## 2. 현재 플랫폼 입력 기반

공유 계약 채널:

```text
com.orialthq.ori_beauty/incoming_share/v1
```

Dart → 네이티브:

- `drainPendingShares`
- `presentCapturePicker` — iOS 전용, Android는 미구현
- `loadAppSnapshot`
- `saveAppSnapshot(snapshot)`
- `acknowledgeShares({ ids })`

네이티브 → Dart:

- `pendingSharesChanged`

`pendingSharesChanged`는 데이터를 직접 싣지 않고 다시 drain하라는
신호입니다. cold start에서 Dart handler가 준비되기 전에 공유 이벤트가
사라지지 않도록 네이티브가 먼저 로컬 pending queue에 저장합니다.

`presentCapturePicker`도 선택한 이미지를 직접 돌려주지 않습니다. 검증과
복사를 마친 뒤 같은 pending queue에 기록하고 `pendingSharesChanged`를
보내므로, snapshot commit이 성공해야 입력이 acknowledge되는 순서가
공유 시트 경로와 동일하게 유지됩니다. 반환값은 수락 여부뿐입니다.

입력 진입점은 플랫폼마다 다르지만 그 뒤 경로는 같습니다.

| 진입점 | Android | iOS |
| --- | --- | --- |
| 공유 시트 (`SEND`/`SEND_MULTIPLE`) | 구현됨 | 미구현 — Share Extension 필요 |
| 캡처 미리보기 `열기` (`VIEW`) | 구현됨 | 해당 없음 |
| 사진 선택기 | 빠른 설정 타일 | 앱 내 `콘텐츠 추가` 시트 |

iOS 선택기는 `PHPickerViewController`를 쓰므로 사진 라이브러리 권한이나
`NSPhotoLibraryUsageDescription`이 필요 없습니다. 검증 규칙과 상한값은
`ios/Runner/Share/`가 `android/.../share/`를 1:1로 옮긴 것이며, 한쪽만
바꾸면 같은 캡처가 플랫폼마다 다르게 거부됩니다.

현재는 `text/plain`, `image/jpeg`, `image/png`, `image/webp`를
노출합니다. 이미지 공유는 임시 URI 권한이 사라지기 전에 MIME signature,
12 MiB 크기, 해상도, 파일 수를 검증하고 앱 전용 저장소로 복사합니다.
수신 자체는 여러 장을 안전하게 보존하지만 현재 분석기는 한 장만
지원하며, 여러 장은 일부를 무시하지 않고 명시적인 실패 상태로 둡니다.

플랫폼 pending queue는 최종 콘텐츠 보관소가 아닙니다. 현재는 Flutter
app snapshot의 동기 commit이 성공한 뒤에만 acknowledge합니다. 이후
로컬 DB repository로 교체하더라도 이 순서는 유지합니다.

## 3. 목표 계층

```text
lib/
├── app/             # 앱 조립과 root navigation
├── core/            # 공통 오류·로깅·버전·테마
├── capture/         # 플랫폼 입력, 원본 보존, 중복 방지
├── analysis/        # 분석 작업, schema 검증, evidence 연결
├── review/          # 사용자 확인·수정·재분석
├── organization/    # 제품 해석, 병합·분리, 파생 보관함
├── domain/          # 플랫폼 중립 데이터 계약
└── storage/         # 로컬 DB와 이후 repository 구현
```

UI 기능 기준으로는 다음 세 화면을 우선합니다.

```text
features/
├── contents/        # 콘텐츠 보관함과 원본 상세
├── products/        # 제품 보관함과 출처별 언급
└── review_queue/    # 확인 필요 결과와 병합 제안
```

비교, 개인 기준, 구매 결정 화면은 현재 베이스라인 내비게이션과 도메인
계약에서 제외합니다.

## 4. 목표 도메인 관계

```text
RawCapture 1 ── 0..1 SourceDocument
SourceDocument 1 ── 0..n ProductMention
SourceDocument 1 ── 0..n Statement
ProductMention 0..n ── 0..1 CanonicalProduct
Statement n ── 1 ProductMention

AnalysisRun 1 ── n DerivedField
DerivedField n ── n EvidenceRef
Correction n ── 1 DerivedField | ProductResolution
OrganizationView ← 위 데이터에서 계산한 파생 읽기 모델
```

### 4.1 RawCapture

플랫폼에서 받은 원본 envelope입니다.

- ID, 수집 시각, 출처 패키지·플랫폼
- 원본 텍스트와 URL
- 정규화된 URL
- 첨부 파일 metadata와 앱 전용 파일 참조
- payload hash
- 사용자 메모
- 입력 계약 버전
- 보존·삭제 상태

분석기가 RawCapture를 수정하면 안 됩니다.

### 4.2 SourceDocument

분석 가능한 자료로 준비된 콘텐츠 표현입니다.

- 텍스트, OCR block, 접근 가능한 metadata
- 콘텐츠 형식, 작성자, 게시 시각, 언어
- 자료 완전성
- 명시적 광고·협찬 표시
- 원본 capture 참조

웹에서 확인되지 않은 값을 URL만으로 채우지 않습니다.

### 4.3 ProductMention

SourceDocument 안에 등장한 제품 표현입니다.

- 원문 브랜드·제품명
- 카테고리, 라인, 옵션, 용량
- canonical product 후보
- 식별 상태와 대안
- 필드별 evidence

한 콘텐츠는 제품이 없거나 여러 제품을 가질 수 있습니다.

### 4.4 CanonicalProduct

같은 실제 제품으로 확인된 언급을 묶는 식별자입니다.

- 정규화된 브랜드·제품·라인·옵션
- 식별 상태
- 연결된 mention
- 병합·분리 이력

가격, 추천 점수, 루틴 중복, 구매 결정은 이 모델에 포함하지 않습니다.

### 4.5 Statement

콘텐츠에서 확인된 진술입니다.

- 원문 excerpt 또는 OCR span
- 연결된 product mention
- 진술 유형과 정규화된 주제
- 명시된 사용 맥락
- evidence

Statement는 제품 사실이 아니라 **특정 출처가 한 말**입니다.

### 4.6 AnalysisRun

파생 결과의 재현성과 차이 추적을 위한 실행 기록입니다.

- analysis run ID
- 시작·종료 시각과 상태
- 입력 schema version
- 출력 schema version
- model·prompt·preprocessor version
- 오류 유형과 재시도 정보

## 5. 원본과 파생 데이터 경계

```text
Immutable
├── RawCapture
├── 사용자가 제공한 attachment
└── AnalysisRun이 참조한 material snapshot

Append-only
├── Analysis result versions
├── Correction events
└── Product merge/split events

Derived
├── 현재 확인된 필드 값
├── 콘텐츠 보관함
├── 제품 보관함
└── 반복 언급 횟수
```

사용자 수정이나 재분석은 이전 값을 삭제하지 않고 새 버전을 만듭니다.
사용자가 전체 삭제를 요청하면 원본, 첨부 파일, 파생 결과, 검색 색인을
같은 삭제 작업으로 처리합니다.

## 6. 처리 상태 머신

```text
received
├── material_ready
│   └── analyzing
│       ├── analyzed
│       │   ├── organized
│       │   └── needs_review ──→ organized
│       └── failed_retryable
├── source_limited
├── unsupported
└── deleted
```

상태 전환 원칙:

- `received`는 durable 저장이 성공한 뒤에만 기록합니다.
- URL 접근 제한은 `failed`가 아니라 `source_limited`입니다.
- schema 검증 실패와 네트워크 오류는 별도 오류 코드로 기록합니다.
- `analyzed`는 schema 검증을 통과한 뒤 제품 해석과 확인 필요 여부를
  판정하는 상태입니다.
- `needs_review`는 제품 정체성, 다제품 여부, 병합처럼 정리 정확도에
  영향을 주는 항목에 사용합니다.
- 오류 후 재시도해도 같은 RawCapture를 재사용합니다.
- 모든 전환은 idempotent해야 합니다.

## 7. 분석 파이프라인

### 7.1 Material preparation

1. 입력 형식과 크기를 검증합니다.
2. URL을 정규화하되 원본 URL을 유지합니다.
3. 플랫폼을 식별합니다.
4. 텍스트와 Luna가 읽은 이미지 evidence를 서로 다른 자료로 만듭니다.
5. 각 자료가 어느 RawCapture에서 왔는지 기록합니다.

사용자 메모는 콘텐츠 원문과 별도 material type으로 유지합니다.

### 7.2 Structured extraction

분석 출력은 자유 형식 문장이 아니라 versioned strict schema로 받습니다.

- 콘텐츠 domain·kind·completeness
- 관찰·추정·누락 상태가 있는 title과 짧은 summary
- 재료 그룹·조리 단계 또는 콘텐츠 facts
- 충돌·경고
- 모든 파생 필드가 참조하는 이미지 evidence

schema를 통과하지 못한 결과는 보관함에 반영하지 않습니다.

### 7.3 Evidence validation

- 사용자에게 노출할 진술마다 최소 한 개의 evidence가 있어야 합니다.
- 텍스트 evidence는 원문 범위와 일치해야 합니다.
- 이미지 evidence는 이미지 번호와 영역을 가져야 합니다.
- evidence가 없는 요약·태그는 폐기하거나 확인 필요로 보냅니다.
- 사용자 메모 근거는 크리에이터의 주장으로 집계하지 않습니다.

### 7.4 Product resolution

1. 정규화된 브랜드·제품·옵션 후보를 만듭니다.
2. 기존 CanonicalProduct와 후보를 비교합니다.
3. 높은 정밀도로 같은 제품임이 확인된 경우에만 자동 연결합니다.
4. 애매하면 신규 미확정 묶음 또는 병합 제안을 만듭니다.
5. 사용자 확인 후 읽기 모델을 다시 계산합니다.

용량 차이, 리뉴얼, 라인명, 옵션을 확인하지 못한 경우 자동 병합하지
않습니다.

## 8. 불확실성 표현

파생 필드는 개념적으로 다음 정보를 가집니다.

```text
DerivedField<T>
├── value
├── status
│   ├── extracted
│   ├── inferred
│   ├── userConfirmed
│   ├── userCorrected
│   └── unknown
├── confidenceScore
├── confidenceBand
├── alternatives[]
├── evidenceRefs[]
└── analysisRunId
```

내부 confidence score는 평가와 threshold 조정에 사용합니다. UI에서는
정밀한 확률처럼 오해하지 않도록 `높음`, `확인 권장`, `확인 필요`의
band를 보여줍니다. 점수가 실제 정확도를 반영하는지 라벨링 데이터로
calibration하기 전에는 자동 확정 기준으로 신뢰하지 않습니다.

## 9. 사용자 수정 계약

수정은 명령과 이벤트로 처리합니다.

- `confirmProductMention`
- `editProductIdentity`
- `addOrRemoveMention`
- `mergeProductGroups`
- `splitProductGroup`
- `editOrRemoveStatement`
- `requestReanalysis`
- `revertCorrection`
- `deleteCapture`

각 `Correction`에는 대상, 이전 값, 새 값, 사용자/시스템 주체, 시각,
선택적인 이유를 기록합니다.

```text
Correction
→ current resolved state 갱신
→ 영향을 받는 OrganizationView 무효화
→ 콘텐츠·제품 보관함 재계산
```

원본과 이전 분석 run은 감사와 디버깅을 위해 유지하되, 사용자 삭제
요청 시 함께 삭제합니다.

## 10. 읽기 모델

쓰기 모델을 UI에 그대로 노출하지 않고 두 개의 파생 view를 만듭니다.

### ContentView

- 원본 미리보기와 출처
- material completeness
- 분석 상태와 확인 필요 수
- 제품 언급과 주제
- 원본·근거 탐색 링크

### ProductView

- canonical product 또는 미확정 후보
- 연결된 콘텐츠와 mention 수
- 출처가 연결된 주제별 진술
- explicit disclosure 집계
- 병합·분리 가능 상태

집계 수치는 원본 레코드에서 계산하며 별도 진실 값처럼 중복 저장하지
않습니다.

## 11. 로컬 저장과 서버 경계

첫 구현에서는 저장소 인터페이스를 다음처럼 분리합니다.

- `CaptureRepository`
- `AnalysisRepository`
- `OrganizationRepository`
- `CorrectionRepository`

로컬 저장은 다음을 보장해야 합니다.

- 앱 재시작 후 RawCapture와 처리 상태 유지
- payload hash 기반 idempotency
- pending queue acknowledge 전 durable write
- attachment의 앱 전용 저장
- 원본과 분석 결과의 일관된 삭제

서버 분석을 추가할 때도 RawCapture ID와 analysis run ID를 idempotency
key로 사용합니다. URL을 서버가 가져온다면 SSRF 방어, redirect 제한,
응답 크기·MIME·시간 제한을 적용합니다.

## 12. 관측성과 품질 이벤트

최소 이벤트:

- `capture_received`
- `capture_persisted`
- `duplicate_detected`
- `material_ready`
- `source_limited`
- `analysis_started`
- `analysis_schema_failed`
- `analysis_completed`
- `review_requested`
- `field_corrected`
- `product_merge_suggested`
- `product_merged`
- `product_split`
- `organized`
- `reanalysis_requested`
- `capture_deleted`

이벤트에는 원문, URL, OCR 내용 같은 민감한 payload를 넣지 않습니다.
처리 시간, 상태, 오류 코드, 입력 형식, schema version만 기록합니다.

중요 품질 계산:

- 원본 보존 성공률
- 분석 가능률
- 제품 식별 정확도
- 잘못된 자동 병합률
- evidence coverage
- 사용자 수정률과 수정 시간
- 24시간 내 정리 완료율
- 삭제 성공률

## 13. 안전과 개인정보 경계

- 공유 텍스트, URL, 이미지 내용을 릴리스 로그에 남기지 않습니다.
- 접근 권한이 없는 SNS 원문이나 영상을 다운로드하지 않습니다.
- attachment는 크기·MIME·파일 수를 검증합니다.
- 서버 업로드와 보존 정책을 사용자에게 명확히 알립니다.
- 동의 없이 원본을 별도 모델 학습 데이터로 사용하지 않습니다.
- 광고 여부는 명시적 표시만 기록합니다.
- 콘텐츠의 주장을 검증된 효능이나 의학적 사실로 표현하지 않습니다.
- 사용자 삭제는 원본, attachment, 분석 결과, 검색 색인을 모두
  포함합니다.

## 14. iOS 확장 방향

후속 iOS Share Extension은 App Group container에 같은 RawCapture
envelope 형태의 manifest를 기록하고 Runner 앱이 drain하는 구조를
사용합니다. Flutter UI, 분석 schema, 제품 정리 도메인은 유지하고
Swift 확장은 원본의 빠른 보존과 저장 확인만 담당합니다.

iOS는 Android 베이스라인이 입력 유실, 분석 정확도, 사용자 수정,
제품 병합 가드레일을 통과한 뒤 시작합니다.

## 15. 이번 범위 전환

이전 프로토타입의 `Product`는 가격, 개인 루틴 중복, 요약 이유,
구매 결정을 한 객체에 담고 있었습니다. 현재 코드에서는 다음처럼
분해했습니다.

```text
IncomingShare   → RawCapture
Product         → ProductMention + CanonicalProduct
reasons         → Statement + EvidenceRef
analysis status → Capture/Analysis/Review 상태 분리
```

`price`, `OverlapLevel`, `Decision`, `UserCriteria`와 관련 화면은 현재
도메인·내비게이션에서 제거했습니다. 광고·협찬 집계는 별도 사실 필드로
추론하지 않고 각 캡처의 명시적 disclosure 관찰 상태에서 계산합니다.
