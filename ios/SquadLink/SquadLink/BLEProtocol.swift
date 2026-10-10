//
//  BLEProtocol.swift
//  SquadLink
//
//  폰 ↔ 자기 단말(NU-40 DK) 사이 1:1 BLE(GATT) 연결의 "약속표".
//  ───────────────────────────────────────────────────────────────
//  왜 GATT 1:1 연결인가?
//   - 단말끼리는 "광고(advertising) 방송"으로 1:N 통신한다(펌웨어 Tap_Talk).
//   - 그러나 아이폰은 '제조사 데이터 광고'를 할 수 없다(iOS 제약).
//     그래서 폰은 방송에 끼어들지 못하고, 대신 '자기 단말'과만 1:1로
//     전선처럼 이어서(GATT) 데이터를 주고받는다. 방송은 단말이 대신 쏜다.
//
//  이 파일은 그 1:1 연결에서 쓸 서비스/캐릭터리스틱 UUID와 데이터 포맷의
//  "초안(draft)"이다. 아직 펌웨어에는 이 GATT 서비스가 없다(광고만 있음).
//  나중에 펌웨어(C)와 이 값들을 1바이트까지 똑같이 맞춰야 한다.
//  ───────────────────────────────────────────────────────────────

import Foundation
import CoreBluetooth

/// 폰↔단말 GATT에서 쓰는 모든 UUID와 바이트 배치를 한곳에 모은 약속표.
///
/// UUID는 커스텀 128bit 초안이다. 베이스는 임의로 뽑은
///   5155xxxx-4252-414E-4753-414E32303236
/// 꼴이며 뒤쪽 ASCII("BRAN GSAN2026")은 과제 식별용 메모일 뿐 의미는 없다.
/// 네 글자(xxxx)만 바꿔 서비스/캐릭터리스틱을 구분한다.
enum BLEProtocol {

    // MARK: - 서비스 / 캐릭터리스틱 UUID (초안)

    /// 우리 앱이 스캔할 때 찾는 유일한 서비스. 이 서비스를 광고하는 기기 = 내 단말.
    static let serviceUUID = CBUUID(string: "51550001-4252-414E-4753-414E32303236")

    /// 폰 → 단말: 최신 GPS(위도·경도·시각)를 써 넣는다. (Write / Write Without Response)
    static let gpsWriteUUID = CBUUID(string: "51550002-4252-414E-4753-414E32303236")

    /// 폰 → 단말: 작성한 메시지(대상 플래그 + UTF-16 텍스트)를 써 넣는다. (Write)
    static let msgWriteUUID = CBUUID(string: "51550003-4252-414E-4753-414E32303236")

    /// 단말 → 폰: 동료/중앙 메시지, 이벤트, 전달확인을 올려 보낸다. (Notify)
    static let statusNotifyUUID = CBUUID(string: "51550004-4252-414E-4753-414E32303236")

    // MARK: - 이벤트 코드 (펌웨어 Tap_Talk.ino 와 동일하게 맞춤)

    enum Event: UInt8 {
        case none       = 0
        case ok         = 1   // 이상 없음
        case sos        = 2   // 긴급 구조
        case enemyFire  = 3   // 적 발견·사격 개시 (방향 동반)
        case ack        = 4   // 메시지 수신 확인
        case enemyHold  = 5   // 적 발견·사격 금지 (방향 동반)
        case correction = 6   // 정정(잘못 봤음)
    }

    // MARK: - 메시지 대상 플래그 (폰 → 단말 msgWrite 의 1바이트)

    enum Target: UInt8 {
        case peer   = 0   // 동료에게 (분대 방송만, 인터넷 X)
        case center = 1   // 중앙에 보냄 (업로드 대상 플래그를 세워 방송)
    }

    // MARK: - 상태 알림 종류 (단말 → 폰 statusNotify 의 1바이트)

    enum StatusKind: UInt8 {
        case peerMessage   = 1   // 동료가 보낸 자유 문장 메시지
        case centerMessage = 2   // 중앙(지휘소)에서 내려온 메시지
        case event         = 3   // 동료/내 이벤트(OK/ALERT/ENEMY 등)
        case deliveryAck   = 4   // "#N 중앙 전달됨 ✅" (내 보고가 중앙에 올라감)
        case peerState     = 5   // 동료 위치/방향/거리 상태 갱신(지도용)
    }

    // ───────────────────────────────────────────────────────────────
    // MARK: - 데이터 포맷 (펌웨어가 구현해야 할 바이트 배치)
    //
    //  모든 정수는 little-endian. 좌표는 정수화해서 보낸다(부동소수 파싱 회피).
    //  lat/lon 을 1e7 로 곱해 Int32 로: 예) 37.1234567° → 371234567.
    //  이 1e7 스케일은 단말 방송(위경도)과도 맞춘다.
    // ───────────────────────────────────────────────────────────────

    static let coordScale: Double = 1e7

    // MARK: 폰 → 단말 : GPS write (총 13바이트 초안)
    //  [0]   version        UInt8  = 1
    //  [1..4] latE7         Int32  LE  (위도 × 1e7)
    //  [5..8] lonE7         Int32  LE  (경도 × 1e7)
    //  [9]   accuracyM      UInt8      (수평 정확도 m, 255=미상) — 실내 품질 판단용
    //  [10..12] ageDeciSec  UInt24 LE  (이 좌표를 폰이 측정한 뒤 경과 0.1초 단위)
    //           → 단말은 "마지막 위치 + 경과 시간"을 방송할 수 있다(폰이 잠깐 끊겨도).
    static func encodeGPS(lat: Double, lon: Double, accuracyM: Double, ageSeconds: Double) -> Data {
        var d = Data()
        d.append(1) // version
        appendInt32LE(&d, Int32((lat * coordScale).rounded()))
        appendInt32LE(&d, Int32((lon * coordScale).rounded()))
        let acc = accuracyM.isFinite ? min(max(accuracyM, 0), 254) : 255
        d.append(UInt8(acc))
        let ageDeci = min(max(Int(ageSeconds * 10), 0), 0xFFFFFF)
        d.append(UInt8(ageDeci & 0xFF))
        d.append(UInt8((ageDeci >> 8) & 0xFF))
        d.append(UInt8((ageDeci >> 16) & 0xFF))
        return d
    }

    // MARK: 폰 → 단말 : 메시지 write (가변 길이)
    //  [0]    version    UInt8  = 1
    //  [1]    target     UInt8  (0=동료, 1=중앙)  — Target
    //  [2]    unitCount  UInt8  (UTF-16 코드유닛 개수)
    //  [3..]  text       UTF-16LE 코드유닛들 (unitCount × 2바이트)
    //  ※ 단말 방송 26바이트 한도 때문에 긴 문장은 단말이 조각내 방송한다
    //    (펌웨어 rxUnits/조각 로직과 짝). 폰은 통째로 넘기고 쪼개기는 단말이 한다.
    static func encodeMessage(target: Target, text: String) -> Data {
        var d = Data()
        d.append(1) // version
        d.append(target.rawValue)
        let units = Array(text.utf16)
        let count = min(units.count, 255)
        d.append(UInt8(count))
        for i in 0..<count {
            let u = units[i]
            d.append(UInt8(u & 0xFF))
            d.append(UInt8((u >> 8) & 0xFF))
        }
        return d
    }

    // MARK: 단말 → 폰 : 상태 notify (가변 길이)
    //  [0]    version    UInt8  = 1
    //  [1]    kind       UInt8  (StatusKind)
    //  [2]    fromId     UInt8  (보낸 단말 ID; 0=중앙/시스템)
    //  [3]    arg1       UInt8  (kind 별 의미 — 아래)
    //  [4]    arg2       UInt8  (kind 별 의미 — 아래)
    //  [5..]  payload    kind 별 가변
    //
    //  kind=peerMessage/centerMessage: 단말이 받은 메시지를 20바이트 조각으로 나눠 보낸다.
    //        arg1=메시지번호, arg2=조각번호<<4 | 조각수, payload = UTF-16LE 텍스트(조각당 최대 7글자)
    //  kind=event: arg1=Event, arg2=0, payload[0..1]=bearing(UInt16 LE, ENEMY일 때)
    //  kind=deliveryAck: arg1=보고번호 #N, arg2=0
    //  kind=peerState: arg1=RSSI(-값을 +로 부호반전한 크기), arg2=distanceBand(0~4),
    //        payload[0..3]=latE7, [4..7]=lonE7, [8..9]=bearing(UInt16 LE)
    //
    //  디코드 결과는 상위에서 쓰기 쉬운 구조체로 바꿔 돌려준다.
    static func decodeStatus(_ data: Data) -> StatusNotification? {
        guard data.count >= 5, data[data.startIndex] == 1,
              let kind = StatusKind(rawValue: data[data.startIndex + 1]) else { return nil }
        let b = [UInt8](data)
        let fromId = b[2]
        let arg1 = b[3]
        let arg2 = b[4]
        switch kind {
        case .peerMessage, .centerMessage:
            var units = [UInt16]()
            var i = 5
            while i + 1 < b.count {
                units.append(UInt16(b[i]) | (UInt16(b[i + 1]) << 8))
                i += 2
            }
            return .messagePart(kind: kind, fromId: fromId, number: arg1,
                                part: Int(arg2 >> 4), parts: Int(arg2 & 0x0F), units: units)
        case .event:
            let ev = Event(rawValue: arg1) ?? .none
            var bearing: UInt16 = 0
            if b.count >= 7 { bearing = UInt16(b[5]) | (UInt16(b[6]) << 8) }
            return .event(fromId: fromId, event: ev, bearing: bearing)
        case .deliveryAck:
            return .deliveryAck(fromId: fromId, reportNumber: arg1)
        case .peerState:
            var latE7: Int32 = 0, lonE7: Int32 = 0
            var bearing: UInt16 = 0
            if b.count >= 15 {
                latE7 = readInt32LE(b, 5)
                lonE7 = readInt32LE(b, 9)
                bearing = UInt16(b[13]) | (UInt16(b[14]) << 8)
            }
            return .peerState(fromId: fromId,
                              rssi: -Int(arg1),
                              distanceBand: Int(arg2),
                              lat: Double(latE7) / coordScale,
                              lon: Double(lonE7) / coordScale,
                              bearing: bearing)
        }
    }

    // MARK: - 바이트 도우미

    private static func appendInt32LE(_ d: inout Data, _ v: Int32) {
        let u = UInt32(bitPattern: v)
        d.append(UInt8(u & 0xFF))
        d.append(UInt8((u >> 8) & 0xFF))
        d.append(UInt8((u >> 16) & 0xFF))
        d.append(UInt8((u >> 24) & 0xFF))
    }

    private static func readInt32LE(_ b: [UInt8], _ i: Int) -> Int32 {
        let u = UInt32(b[i]) | (UInt32(b[i+1]) << 8) | (UInt32(b[i+2]) << 16) | (UInt32(b[i+3]) << 24)
        return Int32(bitPattern: u)
    }
}

/// statusNotify 를 해석한 결과(화면에서 쓰기 쉬운 형태).
enum StatusNotification {
    case messagePart(kind: BLEProtocol.StatusKind, fromId: UInt8, number: UInt8, part: Int, parts: Int, units: [UInt16])
    case event(fromId: UInt8, event: BLEProtocol.Event, bearing: UInt16)
    case deliveryAck(fromId: UInt8, reportNumber: UInt8)
    case peerState(fromId: UInt8, rssi: Int, distanceBand: Int, lat: Double, lon: Double, bearing: UInt16)
}
