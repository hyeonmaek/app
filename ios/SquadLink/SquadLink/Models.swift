//
//  Models.swift
//  SquadLink
//
//  화면에서 쓰는 데이터 묶음(모델)들. UI와 통신 사이의 공용 언어.
//

import Foundation
import CoreLocation

/// 수신/발신 메시지 한 건 (수신 메시지 목록, 보낸 기록에 공용).
struct SquadMessage: Identifiable, Equatable {
    enum Direction { case incoming, outgoing }

    let id = UUID()
    let direction: Direction
    let kind: BLEProtocol.StatusKind   // peerMessage / centerMessage / event / deliveryAck
    let fromId: UInt8                  // 보낸 단말 호출부호(0=중앙/시스템)
    let text: String
    let time: Date
    var acked: Bool = false            // 중앙 메시지를 S1으로 수신 확인했는지

    /// 호출부호 표시용 (E-1, E-2 … / 중앙).
    var callSign: String { callSignOf(fromId) }
}

/// 단말 ID → 호출부호 (보드 화면과 같은 이름). 0은 중앙.
func callSignOf(_ id: UInt8) -> String {
    switch id {
    case 0:    return "중앙"
    case 0xAD: return "E-1"
    case 0xFA: return "E-2"
    default:   return String(format: "ID%02X", id)
    }
}

/// 동료 한 명의 최신 상태 (지도·목록에 쓴다). 지금은 대부분 MOCK으로 채운다.
struct Peer: Identifiable, Equatable {
    let id: UInt8                      // 단말 호출부호 번호
    var coordinate: CLLocationCoordinate2D?
    var enemyBearingDeg: Double?       // 이 동료가 겨눈 적 방향(도). nil이면 화살표 없음
    var distanceBand: Int              // 0 붙음 / 1 1m / 2 2m / 3 5m / 4 10m+
    var lastSeen: Date

    var callSign: String { callSignOf(id) }

    var distanceBandText: String {
        switch distanceBand {
        case 0: return "붙어 있음"
        case 1: return "1m 이내"
        case 2: return "약 2m"
        case 3: return "약 5m"
        default: return "10m 이상"
        }
    }

    static func == (lhs: Peer, rhs: Peer) -> Bool {
        lhs.id == rhs.id &&
        lhs.coordinate?.latitude == rhs.coordinate?.latitude &&
        lhs.coordinate?.longitude == rhs.coordinate?.longitude &&
        lhs.enemyBearingDeg == rhs.enemyBearingDeg &&
        lhs.distanceBand == rhs.distanceBand
    }
}

/// 폰↔단말 연결 상태.
enum LinkState: Equatable {
    case bluetoothOff          // 블루투스 꺼짐/권한 없음
    case idle                  // 대기
    case scanning              // 내 단말을 찾는 중
    case connecting            // 연결 중
    case pairing               // LESC 페어링(6자리) 대기
    case connected             // 연결 + 캐릭터리스틱 발견 완료

    var label: String {
        switch self {
        case .bluetoothOff: return "블루투스 꺼짐"
        case .idle:         return "대기"
        case .scanning:     return "단말 찾는 중…"
        case .connecting:   return "연결 중…"
        case .pairing:      return "페어링 번호 입력"
        case .connected:    return "연결됨"
        }
    }
}
