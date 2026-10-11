# 현맥 · 아이폰 앱

**폰은 단말의 GPS와 키보드입니다.**

현맥 단말에는 GPS도 키보드도 없습니다. 이 앱은 자기 단말과 블루투스로 연결해 위치를 넣어 주고, 분대나 C2로 보낼 메시지를 씁니다.

[firmware](https://github.com/hyeonmaek/firmware) · [app](https://github.com/hyeonmaek/app) · [web](https://github.com/hyeonmaek/web)


![분대원마다 아이폰과 단말이 한 쌍. 폰은 단말에 GPS를 보내고 문자를 주고받는다. 단말끼리는 암호 BLE로 연결되고, 폰끼리는 직접 연결하지 않는다. 단말은 NU-87을 거쳐 C2에 교전·긴급구호·중앙행 문자와 GPS를 보고하고, 명령은 송신 때만 내려온다](docs/images/signals.svg)

## 📍 위치

폰이 2초마다 자기 단말에 GPS 좌표를 넣어 둡니다. 단말이 사격개시나 긴급구호를 보낼 때 이 좌표가 암호화된 방송에 함께 실려 C2 지도에 찍힙니다.

## 💬 메시지

아이폰은 iOS 제약으로 분대 방송에 직접 낄 수 없습니다. 그래서 폰은 자기 단말과만 연결하고, 방송은 단말이 대신 합니다. 받는 쪽은 분대 또는 C2 중에서 고릅니다. 단말이 받은 C2 명령과 동료 메시지도 앱에 그대로 쌓입니다.

## 🔒 연결 보안

단말 화면에 뜬 6자리 번호를 입력해야 연결됩니다. 다시 연결할 때도 매번 번호를 묻고, 틀리면 바로 알려 줍니다.

| 키워드 | 쓰임 |
|---|---|
| CoreBluetooth GATT | 자기 단말과 1:1 연결 |
| BLE LESC Passkey | 6자리 번호 인증, 중간자 공격 방지 |
| SwiftUI | 화면 |
| MapKit | 지도 |

## 🛠 빌드

Xcode 15, iOS 17 이상. `ios/SquadLink/SquadLink.xcodeproj`를 열고 Signing에서 자기 Team을 고른 뒤 실행합니다.
