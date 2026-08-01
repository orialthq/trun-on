# iOS 팀원 실행 가이드

저장소: <https://github.com/orialthq/ori-beauty>

Ori Beauty는 Flutter로 화면과 도메인 로직을 공유하지만, 현재 입력 파이프라인은
Android 우선으로 구현되어 있습니다. iOS 팀원은 지금 바로 화면과 정리 흐름을
실행하고 Flutter 코드를 함께 개발할 수 있습니다. 다만 iPhone의 스크린샷 공유
메뉴에서 Ori Beauty로 보내는 기능은 아직 사용할 수 없습니다.

## 현재 iOS 지원 범위

| 기능 | iOS 시뮬레이터 | 실제 iPhone | 현재 상태 |
| --- | --- | --- | --- |
| 앱 빌드와 실행 | 가능 | 서명 설정 후 가능 | Flutter UI 실행 가능 |
| 샘플 콘텐츠 탐색 | 가능 | 가능 | 목록·상세·정리함 UI 확인 가능 |
| 텍스트 직접 추가 | 가능 | 가능 | 현재 실행 중에는 보이지만 재시작 후 보존되지 않음 |
| Flutter 테스트 | 가능 | 해당 없음 | Dart·widget 범위이며 iOS 네이티브 연동은 별도 검증 필요 |
| 스크린샷을 Ori로 공유 | 불가 | 불가 | iOS Share Extension 미구현 |
| 공유 입력 영구 저장 | 불가 | 불가 | iOS 네이티브 저장 채널 미구현 |
| 스크린샷 Luna 분석 | 불가 | 불가 | iOS 이미지 입력과 서버 연결 작업 필요 |

2026년 8월 1일 기준으로 `flutter build ios --simulator --debug
--no-codesign` 빌드와 iPhone 17 Pro 시뮬레이터 실행을 확인했습니다.

## 준비물

- macOS와 Xcode
- Flutter `3.44.8`, Dart `3.12.2` 또는 프로젝트와 호환되는 최신 버전
- Git
- Node.js 20 이상 — 분석 서버를 수정하거나 테스트할 때만 필요

먼저 환경을 확인합니다.

```bash
flutter doctor
xcodebuild -version
```

`flutter doctor`의 Xcode 항목에 문제가 있으면 Xcode를 한 번 실행해 라이선스와
추가 구성 요소 설치를 완료한 뒤 다시 확인하세요.

## 가장 빠른 실행 방법

```bash
git clone https://github.com/orialthq/ori-beauty.git
cd ori-beauty
git checkout main
flutter pub get
flutter analyze --fatal-infos
flutter test
open -a Simulator
flutter devices
flutter run -d "<iPhone 시뮬레이터 ID>"
```

예를 들어 `flutter devices`에 표시된 ID가 `08EACE77-...`라면 마지막 명령은
다음과 같습니다.

```bash
flutter run -d 08EACE77-...
```

시뮬레이터 빌드만 확인하려면 다음 명령을 실행합니다. 시뮬레이터 빌드에는
Apple Developer 서명이 필요하지 않습니다.

```bash
flutter build ios --simulator --debug --no-codesign
```

## 지금 iOS에서 확인할 수 있는 것

- 콘텐츠 목록, 필터, 상세 화면과 정리함 UI
- 샘플 데이터의 뷰티 제품·리뷰·출처 표시
- 긴 원문의 접기·펼치기 동작
- 텍스트 직접 추가 후 분석·확인 흐름
- Dart 도메인 모델, 분석 스키마, 상태 관리와 위젯 테스트
- 서버 코드의 단위 테스트

서버 테스트는 앱 실행과 별개입니다.

```bash
cd server
npm test
```

OpenAI API 키나 로컬 분석 서버는 샘플 UI를 실행하는 데 필요하지 않습니다.
실제 캡처 이미지는 저장소나 공개 Issue에 올리지 마세요.

## 아직 iOS에서 확인할 수 없는 것

Android에 구현된 다음 경로는 iOS에서 아직 동작하지 않습니다.

```text
스크린샷 촬영
→ 공유 시트 또는 캡처 미리보기에서 Ori Beauty 선택
→ 원본을 앱 내부로 복사
→ Luna 분석
→ 결과와 원본을 재실행 후에도 복원
```

현재 iOS 프로젝트에는 Share Extension과 App Group이 없고, Android가 제공하는
`com.orialthq.ori_beauty/incoming_share/v1` 메서드 채널의 Swift 구현도 없습니다.
따라서 앱 화면이 실행된다는 것과 스크린샷 입력이 지원된다는 것은 구분해야
합니다. 텍스트 직접 추가도 화면에서는 동작하지만, iOS에서는 현재 네이티브
snapshot 저장 구현이 없어 앱 재시작 후에는 사라집니다.

## 실제 iPhone에서 UI 실행하기

USB 또는 무선으로 iPhone을 Mac에 연결한 뒤 Xcode에서 다음 설정이 필요합니다.

1. `ios/Runner.xcworkspace`를 Xcode로 엽니다.
2. Runner target의 **Signing & Capabilities**에서 팀과 고유 Bundle Identifier를
   설정합니다.
3. iPhone에서 개발자 모드를 켜고 이 Mac을 신뢰합니다.
4. `flutter devices`에서 기기 ID를 확인합니다.
5. `flutter run -d "<iPhone 기기 ID>"`를 실행합니다.

이 단계는 현재 Flutter UI를 실제 기기에서 보는 용도입니다. 스크린샷 공유 입력과
Luna 분석까지 검증하는 절차는 아닙니다.

## iOS 입력 파이프라인을 완성하려면

1. iOS Share Extension target을 추가합니다.
2. Runner와 Extension이 공유할 App Group 컨테이너를 구성합니다.
3. 이미지 MIME·크기·해상도를 검증하고 공유 컨테이너에 안전하게 복사합니다.
4. pending queue, acknowledge, snapshot 저장을 Swift로 구현해 Flutter 메서드
   채널과 연결합니다.
5. 실제 iPhone에서 접근 가능한 HTTPS 분석 서버를 사용하거나, Mac의 로컬 서버를
   쓸 경우 iOS 로컬 네트워크 권한과 주소 설정을 추가합니다.
6. 실제 기기에서 백그라운드·중복 입력·앱 재시작·실패 복구를 검증합니다.

Android 동작을 그대로 Dart 코드만으로 옮길 수 있는 부분은 이미 공유됩니다.
새로 필요한 작업은 주로 iOS의 공유 진입점, 파일 보존, 네트워크와 서명 설정입니다.

## 브랜치와 PR

```bash
git checkout main
git pull --ff-only
git checkout -b feature/ios-share-extension
```

작업 후 본인 브랜치를 push하고 `main`을 대상으로 Pull Request를 만드세요.
공개 저장소이므로 테스트용 캡처는 식별 정보가 없는 더미 이미지로만 추가합니다.
