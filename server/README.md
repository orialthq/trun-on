# 챙김 capture analysis server

Flutter 앱과 OpenAI 사이에서 이미지 분석을 수행하는 로컬 프록시입니다. API
키는 앱이나 저장소에 포함하지 않으며, 요청 이미지·Base64·OpenAI 응답 내용도
로그에 남기지 않습니다.

## 요구 사항

- Node.js 20 이상
- macOS 개발 환경에서는 키체인 서비스 `ori-beauty-openai`, 계정
  `ori-beauty`에 저장된 OpenAI API 키

키체인 식별자는 기존 로컬 개발 환경과의 호환을 위해 현재 이름을 유지합니다.

외부 npm 의존성은 없습니다.

## 실행

저장된 키를 화면에 출력하지 않고 키체인에서 환경변수로 옮겨 실행합니다.

```sh
cd server
npm run dev
```

기본 주소는 `http://127.0.0.1:8787`입니다. Android 에뮬레이터에서는 호스트
루프백을 `http://10.0.2.2:8787`로 접근합니다.

직접 실행할 때는 `OPENAI_API_KEY`가 환경변수에 있어야 합니다.

```sh
cd server
npm start
```

`HOST`와 `PORT` 환경변수로 수신 주소를 바꿀 수 있습니다. 실제 기기에서 같은
Wi-Fi를 통해 개발 서버에 연결할 때만 `HOST=0.0.0.0`을 사용하고, 운영 환경에는
인증·TLS·요청 제한이 있는 별도 배포 계층을 두세요.

## API

### `GET /health`

키나 사용자 콘텐츠를 노출하지 않는 상태 확인 응답입니다.

### `POST /v1/analyze`

`Content-Type: application/json`

```json
{
  "image": {
    "mimeType": "image/jpeg",
    "base64": "<data URL 접두사 없이 순수 Base64>"
  },
  "capture": {
    "id": "capture-001",
    "sourceApp": "instagram",
    "sourceUrl": "https://www.instagram.com/p/example/",
    "capturedAt": "2026-07-31T12:00:00+09:00",
    "locale": "ko-KR"
  }
}
```

`capture.id`만 필수이며 나머지 캡처 필드는 생략하거나 `null`로 보낼 수 있습니다.
지원 형식은 JPEG, PNG, WEBP이며 실제 파일 시그니처와 MIME이 일치해야 합니다.
기본 이미지 제한은 12 MiB입니다.

성공 응답은 Flutter에서 바로 파싱할 수 있는 단일 객체입니다.

```json
{
  "schemaVersion": "1.0",
  "model": "gpt-5.6-luna",
  "domain": "food",
  "contentKind": "recipe",
  "completeness": "partial",
  "title": {
    "value": "된장찌개",
    "status": "observed",
    "confidence": 0.98,
    "evidenceIds": ["e1"]
  },
  "summary": "화면에 보이는 된장찌개 재료와 조리 순서예요.",
  "evidence": [
    {
      "id": "e1",
      "text": "된장찌개",
      "region": "overlay",
      "confidence": 0.99
    }
  ],
  "ingredientGroups": [],
  "steps": [],
  "facts": [],
  "conflicts": [],
  "warnings": ["일부 재료의 양이 화면에 보이지 않아요."]
}
```

분류 enum:

- `domain`: `beauty | food | unknown`
- `contentKind`: `beauty_product | recipe | sauce_recipe |
  commerce_product | product_review | menu_comparison | unknown`
- `completeness`: `complete | partial | conflicted | needs_review |
  unsupported`

서버는 결과의 모든 `evidenceIds`가 실제 `evidence[].id`를 참조하는지 확인합니다.
불일치하거나 구조가 잘못된 모델 응답은 앱으로 전달하지 않습니다.

오류는 항상 같은 형태입니다.

```json
{
  "error": {
    "code": "INVALID_IMAGE",
    "message": "이미지 형식과 데이터가 일치하지 않아요.",
    "retryable": false,
    "requestId": "..."
  }
}
```

## OpenAI 요청 정책

- Responses API의 `gpt-5.6-luna`
- `store: false`
- 이미지 `detail: original`
- `reasoning.effort: low`
- strict JSON Schema Structured Outputs
- 이미지 속 문구를 명령이 아닌 신뢰하지 않는 원문으로 취급
- 캡처 ID·전체 URL·쿼리·수집 시각은 모델에 보내지 않고, 정규화된 출처
  앱·호스트·locale만 출처 문맥으로 전달

## 테스트

```sh
cd server
npm test
```

테스트는 의존성 주입된 가짜 transport/fetch만 사용하므로 OpenAI API를 호출하거나
비용을 발생시키지 않습니다.
