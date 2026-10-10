# 현맥 (HYEONMAEK, 玄脈) — 아이폰 앱 (SquadLink)

> 분대를 끊김 없이 잇는 검고 깊은 줄기. *The dark vein that keeps a squad connected.*

D4D × EDTH SEOUL 2026 해커톤 출품작의 병사용 폰 앱. 자기 단말(NU-40 DK)과 블루투스로 1:1 연결해, 폰 GPS를 단말에 넣어 주고 메시지를 주고받는다.

## 화면

- **연결**: 주변 단말 목록 → 고르면 단말 화면에 뜬 6자리 번호로 페어링(틀리면 다시 입력). 재연결 때도 매번 번호 필요
- **메시지**: 받은 메시지(중앙·동료)와 보낸 메시지. 오른쪽 위 작성 버튼 → 받는 쪽(분대 / 중앙) 선택 후 전송
- **지도**: 위성 지도, 내 위치

## 동작

- 2초마다 폰 GPS를 단말에 기록 → 단말이 사격개시·긴급구호를 보낼 때 좌표가 함께 C2로 올라간다
- "중앙"으로 보낸 메시지는 단말 → 기지국 → C2 서버로 전달된다
- 단말이 받은 중앙 명령·동료 메시지는 폰 메시지 탭에도 기록된다

## 빌드

Xcode 15 이상, iOS 17 이상.

1. `ios/SquadLink/SquadLink.xcodeproj` 열기
2. Signing & Capabilities에서 자기 Team 선택
3. 아이폰 연결(개발자 모드 켜기) 후 ▶

`web/squadphone.html`: 같은 기능의 크롬 Web Bluetooth 판(안드로이드·데스크톱 크롬용 보조).

## 관련 저장소

- 단말·기지국 펌웨어: [hyeonmaek/firmware](https://github.com/hyeonmaek/firmware)
- C2 웹(지휘소 화면·서버): [hyeonmaek/web](https://github.com/hyeonmaek/web)
