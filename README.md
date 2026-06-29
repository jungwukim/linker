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

## 빌드
```bash
xcodegen generate
open Linker.xcodeproj   # iPhone 시뮬레이터로 Run
```
설정 탭에서 AI API 키를 입력. 유튜브 자막·갤러리는 `backend/`를 배포(Vercel)한 뒤
설정의 "YouTube 백엔드 URL"에 주소를 넣으면 안정적으로 동작.

## 백엔드
`backend/README.md` 참고. `cd backend && vercel` 로 배포.
데이터센터 IP가 유튜브 봇 차단에 걸리면 `YT_COOKIES` 환경변수로 로그인 쿠키를 전달.

## 메모 / 알려진 한계
- 유튜브는 비로그인 직접 스크래핑이 불안정해 백엔드(yt-dlp) 경유를 권장.
- 일부 자동생성 자막은 직접 경로로는 비어 있을 수 있음(백엔드는 정상 추출).
