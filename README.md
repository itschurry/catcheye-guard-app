# CatchEye Guard App

`catcheye-guard` 실행 파일을 제어하고, ROI JSON을 편집하고, 실시간 프리뷰 스트림과 로그를 확인하기 위한 Flutter 데스크톱 앱입니다.

현재 코드는 Linux 데스크톱 환경을 기준으로 작성되어 있으며, 외부 `catcheye-guard` 바이너리와 함께 사용하는 운영 도구 성격의 프로젝트입니다.

## 주요 기능

- `Dashboard`
  - `catcheye-guard` 프로세스 시작/중지
  - 프로세스 상태, ROI 파일, 활성 존 수, 최근 로그 확인
- `Viewer`
  - Unix domain socket으로 전달되는 JPEG 프레임 스트림 표시
  - 연결 상태, FPS, 누적 프레임 수 확인
- `ROI Editor`
  - ROI JSON 파일 열기/새로 만들기/저장/다른 이름으로 저장
  - 존 추가/삭제/이름 변경/활성화 토글
  - 포인트 드래그 편집 및 포인트 추가
  - 이미지 크기 기준 유효성 검사
- `Settings`
  - 실행 파일, 모델 파일, 메타데이터, ROI 파일 경로 설정
  - 현재 로드된 ROI 구성 요약 확인
- `Logs`
  - 특정 `.log` 파일 또는 디렉터리의 최신 로그 파일 tail 확인

## 화면 구성

- `Dashboard`: 전체 상태 요약과 프로세스 제어
- `Viewer`: 프리뷰 스트림 연결 및 실시간 표시
- `ROI Editor`: ROI 폴리곤 편집
- `Settings`: 외부 파일 경로 설정
- `Logs`: 로그 파일 모니터링

## 기술 스택

- Flutter
- Dart
- `provider`
- `file_picker`

## 프로젝트 구조

```text
lib/
  main.dart                    앱 진입점 및 네비게이션
  models/                      설정/ROI 데이터 모델
  providers/                   상태 관리
  screens/                     각 화면 UI
  services/                    프로세스 실행, 프레임 수신, ROI 파일 입출력
  widgets/                     ROI 캔버스, 뷰어, 존 편집 패널
linux/                         Linux 데스크톱 러너
test/                          위젯 테스트
```

## 실행 환경

다음 환경을 전제로 합니다.

- Flutter SDK 설치
- Linux 데스크톱 타깃 사용 가능 환경
- 외부 실행 파일 `catcheye-guard`
- 필요 시 모델/메타데이터/ROI 설정 파일
  - `.param`
  - `.bin`
  - `.yaml` 또는 `.yml`
  - `.json`

`pubspec.yaml` 기준 SDK 제약은 `Dart ^3.11.1` 입니다.

## 실행 방법

의존성 설치:

```bash
flutter pub get
```

Linux 데스크톱으로 실행:

```bash
flutter run -d linux
```

테스트 실행:

```bash
flutter test
```

## 기본 사용 흐름

1. `Settings`에서 `catcheye-guard` 실행 파일 경로를 지정합니다.
2. 필요하면 모델 `.param`, `.bin`, 메타데이터 `.yaml`, ROI `.json` 경로를 입력합니다.
3. `ROI Editor`에서 ROI 파일을 열거나 새로 만들어 수정하고 저장합니다.
4. `Dashboard`에서 `Start`를 눌러 외부 프로세스를 실행합니다.
5. 프리뷰가 필요한 경우 `Viewer`에서 소켓에 연결합니다.
6. 실행 로그는 `Dashboard` 또는 `Logs` 화면에서 확인합니다.

## 외부 프로세스 연동 방식

앱은 `Dashboard`의 `Start` 버튼을 누르면 설정값으로 외부 바이너리를 실행합니다.

현재 코드 기준 실행 인자는 다음 순서의 위치 인자로 전달됩니다.

1. 모델 파라미터 파일 경로
2. 모델 바이너리 파일 경로
3. 메타데이터 파일 경로
4. ROI JSON 파일 경로
5. `--stream`

즉, 외부 `catcheye-guard` 실행 파일은 위 형식의 인자를 받을 수 있어야 하며, `--stream` 사용 시 프리뷰 프레임을 Unix 소켓으로 송신해야 합니다.

## 프리뷰 스트림 프로토콜

`Viewer`는 기본적으로 아래 소켓 경로에 연결하도록 되어 있습니다.

```text
/tmp/catcheye_guard_preview.sock
```

수신 프로토콜은 다음과 같습니다.

```text
[4-byte little-endian uint32 frame_size][JPEG bytes]
```

프레임은 JPEG 바이트 배열이어야 하며, 각 프레임 앞에 4바이트 길이 헤더가 붙습니다.

## ROI JSON 형식

ROI 편집기는 아래 구조의 JSON을 사용합니다.

```json
{
  "camera_id": "cam_default",
  "image_width": 1280,
  "image_height": 720,
  "allowed_zones": [
    {
      "id": "zone_1",
      "name": "entrance",
      "enabled": true,
      "points": [
        [120.0, 100.0],
        [600.0, 110.0],
        [640.0, 420.0],
        [140.0, 430.0]
      ]
    }
  ]
}
```

유효성 검사 기준:

- `image_width`, `image_height`는 0보다 커야 함
- 각 존은 최소 3개의 포인트를 가져야 함
- 모든 포인트는 이미지 경계 안에 있어야 함

## 현재 구현 기준 참고 사항

- 설정값은 메모리에만 유지되며 앱 재시작 후 자동 복원되지 않습니다.
- `Settings`의 일부 항목(`cameraPipeline`, `roiEnabled` 등)은 UI에는 있으나 현재 실행 인자에 반영되지 않습니다.
- ROI 기본 자동 로드는 특정 고정 경로를 후보로 검사하는 형태로 구현되어 있습니다.
- 플랫폼 코드는 현재 `linux/`만 포함되어 있어 사실상 Linux 데스크톱 사용이 전제됩니다.

## 개발 메모

- 상태 관리는 `provider` 기반입니다.
- 프로세스 실행 로그는 앱 내부에서 별도로 수집해 `Dashboard`에 표시합니다.
- `Logs` 화면은 파일 시스템을 1초 주기로 폴링합니다.

