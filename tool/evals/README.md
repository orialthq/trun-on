# Private local holdout eval

이 도구는 17개의 비공개 이미지 샘플을 로컬 분석 백엔드에 보내고,
`domain`, `contentKind`, `completeness`와 안전한 오류 코드 규칙만 평가합니다. 저장소에는
실제 JPG, 계정명, 캡션, URL, 레시피 본문을 넣지 않습니다.

## 개인정보 경계

- 추적되는 manifest에는 `holdout-01` 같은 불투명 ID와 시나리오 enum만
  둡니다.
- 원본 파일명도 계정명이나 콘텐츠 제목 대신 `holdout-NN.jpg`를
  사용합니다.
- 실제 이미지, 선택적 공유 텍스트, 작업 manifest는
  `tool/evals/local/` 아래에만 둡니다. 이 폴더는 이 디렉터리의
  `.gitignore`에서 제외됩니다.
- 이미지에 계정명이나 저작권 있는 레시피가 보여도 이를 manifest나
  테스트 fixture로 옮겨 적지 않습니다.
- 실행기는 `localhost`, `127.0.0.1`, `::1` 주소만 허용합니다. 쿼리
  문자열이나 URL credential도 거부하며 HTTP redirect를 따라가지
  않습니다.
- API key, 이미지 bytes, 공유 텍스트, 백엔드 원문 응답은 stdout,
  stderr, aggregate JSON에 기록하지 않습니다.
- aggregate에는 불투명 sample ID, enum 판정, 제한된 오류 code만
  남습니다. 백엔드의 오류 message는 의도적으로 버립니다.

이 보호는 git 유출을 막기 위한 베이스라인입니다. 로컬 백엔드가 별도
로그를 남기는 경우에는 그 백엔드의 로그·보존 정책도 따로 확인해야
합니다.

## 로컬 폴더 준비

프로젝트 루트에서 다음 구조를 만듭니다.

```text
tool/evals/local/
├── manifest.json
└── samples/
    ├── holdout-01.jpg
    ├── ...
    └── holdout-17.jpg
```

```sh
mkdir -p tool/evals/local/samples
cp tool/evals/manifest.template.json tool/evals/local/manifest.json
```

비공개 JPG 17개를 로컬에서 `holdout-01.jpg`부터
`holdout-17.jpg`까지 매핑합니다. 번호와 시나리오의 관계는
`manifest.template.json` 순서를 따릅니다. 실제 계정명이나 제목을
파일명에 넣지 않습니다.

텍스트 내용을 manifest 자체에 넣는 필드는 지원하지 않습니다. 알 수
없는 필드가 있으면 manifest validation이 실패합니다.

## 백엔드 계약

기본 endpoint는 `http://127.0.0.1:8787/v1/analyze`이며 앱과 같은 다음 JSON을
POST 합니다.

```json
{
  "image": {
    "mimeType": "image/jpeg",
    "base64": "<local bytes>"
  },
  "capture": {
    "id": "holdout-01",
    "sourceApp": "private-eval",
    "sourceUrl": null,
    "capturedAt": null,
    "locale": "ko-KR"
  }
}
```

응답은 분석 객체를 최상위에 제공해야 합니다.

```json
{
  "domain": "food",
  "contentKind": "recipe",
  "completeness": "complete"
}
```

지원 enum:

- domain: `food`
- contentKind: `recipe`, `sauce_recipe`, `commerce_product`,
  `product_review`, `menu_comparison`
- completeness: `complete`, `partial`, `conflicted`, `needs_review`

사람이 근거 화면을 다시 확인해도 두 판정이 모두 안전한 경계 사례만
`allowedCompleteness`로 보조 판정을 허용합니다. 기본 `completeness`는
선호 판정이고, 이 필드는 모델 결과를 사후에 맞추는 용도로 사용하지
않습니다.

## 실행

```sh
export ORI_EVAL_ENDPOINT=http://127.0.0.1:8787/v1/analyze
dart run tool/evals/run_local_eval.dart
```

인증이 필요한 로컬 백엔드에서는 key를 환경 변수로만 전달합니다.
값은 `Authorization: Bearer` 헤더로 보내며 출력이나 결과 파일에
기록하지 않습니다.

```sh
export ORI_EVAL_API_KEY='local-only-secret'
dart run tool/evals/run_local_eval.dart
```

특정 샘플만 다시 실행할 수 있습니다. 전체 manifest는 여전히 17개
시나리오를 모두 포함해야 합니다.

```sh
dart run tool/evals/run_local_eval.dart --sample holdout-06
```

기본 결과는 gitignore된 `tool/evals/reports/latest.json`에 생성됩니다.
종료 코드는 모두 통과하면 `0`, 평가 실패가 하나라도 있으면 `1`입니다.
설정·입력 오류에는 별도 non-zero 코드가 사용됩니다.

## Aggregate JSON

결과에는 전체 pass/fail 수, 시나리오별 집계, 필드별 판정만 포함됩니다.

```json
{
  "schemaVersion": 1,
  "totals": {"samples": 17, "passed": 15, "failed": 2},
  "byScenario": {
    "recipe_partial_mixed_text": {
      "total": 1,
      "passed": 1,
      "failed": 0
    }
  },
  "results": [
    {
      "sampleId": "holdout-01",
      "scenario": "recipe_partial_mixed_text",
      "passed": true,
      "checks": []
    }
  ]
}
```

## 테스트

mock backend 테스트에는 실제 이미지나 텍스트를 사용하지 않습니다.

```sh
flutter test test/evals
flutter analyze --fatal-infos
```

## Git ignore

`tool/evals/.gitignore`가 `local/`과 `reports/`를 막으므로 현재 구조에는
루트 `.gitignore` 변경이 필요 없습니다. 비공개 샘플이나 결과 경로를
이 디렉터리 밖으로 옮긴다면 루트 `.gitignore`에도 해당 경로를
추가해야 합니다.
