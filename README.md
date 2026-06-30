# linker

여러 서비스(YouTube·Instagram·Threads·X·Facebook·메모 등)에서 "나중에 보기"로 흩어진
콘텐츠를 **공유 버튼 / 클립보드 붙여넣기**로 모아, AI가 분석·인덱싱하고 한곳에서 검색하는 iOS 앱.

## 구성
- **`Linker/`, `Shared/`, `ShareExtension/`** — iOS 앱 (SwiftUI, iOS 17+, XcodeGen `project.yml`)
- **`backend/`** — yt-dlp 기반 Vercel Python 함수 (유튜브 자막·구간 프레임 추출)

## 주요 기능
- 공유 시트 + 클립보드 붙여넣기 캡처
- 다중 AI 제공자(Claude / OpenAI / Gemini) — 설정에서 제공자·모델·키 선택
- 요약·태그·주제·핵심 키워드 + **유튜브 전체 스크립트(타임스탬프)·중요 구간·구간 미리보기 갤러리**
- 중요 구간/프레임 탭 → 해당 타임스탬프로 유튜브 열기
- 시맨틱 + 키워드 검색, 태그/주제 필터, iCloud(CloudKit) 동기화

## 유튜브 추출 방식 (로그인 불필요)
- **온디바이스 1순위**: 앱이 폰의 가정용 IP로 유튜브에 직접 요청 → 로그인/쿠키 없이
  자막·미리보기 프레임을 가져옴 (`TranscriptFetcher`, `StoryboardFetcher`).
- **백엔드 폴백**: 직접 추출이 비면 배포된 yt-dlp 백엔드(`backend/`)가 받쳐줌.
  백엔드도 쿠키 없이 동작하며, 기본 URL이 앱에 내장돼 있어 별도 설정 없이 쓸 수 있음.
- 분석에 필요한 건 유튜브 로그인이 아니라 **설정에 넣은 AI API 키**뿐.

## 빌드
```bash
xcodegen generate
open Linker.xcodeproj   # iPhone 시뮬레이터로 Run
```
설정 탭에서 AI API 키만 입력하면 됨. 백엔드 URL은 기본값이 내장돼 있고,
직접 배포한 주소로 바꾸려면 설정 → "YouTube 백엔드 URL"에서 변경.

## 백엔드 (선택/폴백)
`backend/README.md` 참고. `cd backend && vercel --prod` 로 배포.
> ⚠️ 보안: 봇 차단이 잦은 일부 영상을 위해 `YT_COOKIES`(로그인 쿠키)를 넣을 수도 있으나,
> **메인 계정 쿠키는 계정 세션 전체가 노출**되므로 권장하지 않음. 꼭 필요하면 일회용 부계정 쿠키만 사용.

## 메모 / 알려진 한계
- 온디바이스(폰 IP) 경로라 로그인 없이도 대부분의 영상이 잘 됨.
- 단, 연령·지역 제한, 라이브, 자막 없는 영상은 전체 스크립트가 비거나 약할 수 있음
  (요약·태그는 정상 생성).
- 전체 스크립트는 줄 단위 `LazyVStack`으로 렌더해 긴 자막에서도 화면이 끊기지 않음.
