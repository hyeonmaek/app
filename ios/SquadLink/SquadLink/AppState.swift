//
//  AppState.swift
//  SquadLink
//
//  앱 전체의 "뇌". BLE·GPS·화면 상태를 한곳에서 들고 조율한다.
//   - 2초마다 최신 GPS를 단말에 write
//   - 단말이 올려주는 statusNotify를 받아 메시지/동료/이벤트 목록에 반영
//   - MOCK 모드: 단말 없이 가짜 동료 2명과 메시지를 흘려 UI를 전부 돌려본다
//

import Foundation
import Combine
import SwiftUI
import CoreLocation

@MainActor
final class AppState: ObservableObject {

    // 하위 매니저
    let ble = BLEManager()
    let location = LocationManager()

    // 화면이 구독하는 상태
    @Published var link: LinkState = .idle
    @Published var messages: [SquadMessage] = []      // 수신+발신 섞인 타임라인(최신이 위)
    @Published var peers: [Peer] = []                 // 동료 목록(지도·목록)
    @Published var myCallSign: String = "단말 미연결"
    @Published var lastDeliveryNumber: Int?           // "#N 중앙 전달됨 ✅"
    @Published var squadKeyLoaded: Bool = false
    @Published var found: [BLEManager.FoundDevice] = []   // 찾은 단말 목록(화면 표시용으로 BLE에서 복사)
    @Published var lastError: String?

    private var cancellables = Set<AnyCancellable>()
    private var partial: [String: [Int: [UInt16]]] = [:]   // 조각 모으는 중인 받은 메시지
    private var doneKeys: [String] = []                     // 이미 목록에 넣은 메시지(중복 방지)
    private var gpsTimer: Timer?

    init() {
        squadKeyLoaded = KeychainStore.loadSquadKey() != nil

        // BLE 상태를 그대로 link로 반영. 연결되면 단말 이름을 내 호출부호로 쓴다(표기 통일).
        ble.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] s in
                guard let self else { return }
                self.link = s
                if s == .connected {
                    self.myCallSign = Self.callSign(from: self.ble.discoveredName)
                } else if s == .idle || s == .bluetoothOff {
                    self.myCallSign = "단말 미연결"
                }
            }
            .store(in: &cancellables)

        ble.$lastError
            .receive(on: RunLoop.main)
            .sink { [weak self] e in self?.lastError = e }
            .store(in: &cancellables)

        // 찾은 단말 목록을 화면이 따라가도록 그대로 복사.
        ble.$found
            .receive(on: RunLoop.main)
            .sink { [weak self] list in self?.found = list }
            .store(in: &cancellables)

        // 단말이 올려주는 알림 처리.
        ble.onStatus = { [weak self] note in
            Task { @MainActor in self?.handle(note) }
        }

        location.start()
        startGPSTimer()
    }

    // MARK: - 연결 제어

    /// "SQUAD-E2" → "E-2" 로 호출부호 추출.
    static func callSign(from name: String?) -> String {
        guard let n = name else { return "단말" }
        if let r = n.range(of: "SQUAD-") { return String(n[r.upperBound...]) }
        return n
    }

    func scan() { ble.startScan() }

    func connect(to device: BLEManager.FoundDevice) {
        ble.connect(to: device.peripheral)
    }

    func disconnect() {
        ble.stop()
    }

    // MARK: - GPS 주기 전송 (2초)

    private func startGPSTimer() {
        gpsTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.pushGPS() }
        }
    }

    private func pushGPS() {
        guard link == .connected, let loc = location.lastLocation else { return }
        let age = -loc.timestamp.timeIntervalSinceNow
        ble.writeGPS(lat: loc.coordinate.latitude,
                     lon: loc.coordinate.longitude,
                     accuracyM: loc.horizontalAccuracy,
                     ageSeconds: age)
    }

    // MARK: - 메시지 보내기

    func send(text: String, toCenter: Bool) {
        let target: BLEProtocol.Target = toCenter ? .center : .peer
        ble.writeMessage(target: target, text: text)
        let msg = SquadMessage(direction: .outgoing,
                               kind: toCenter ? .centerMessage : .peerMessage,
                               fromId: 0, text: text, time: Date())
        messages.insert(msg, at: 0)
    }

    /// 중앙 메시지 수신 확인(S1).
    func ack(_ message: SquadMessage) {
        if let idx = messages.firstIndex(where: { $0.id == message.id }) {
            messages[idx].acked = true
        }
        // 실제로는 메시지 번호가 필요. 초안이라 0 전송.
        ble.sendAck(messageNumber: 0)
    }

    // MARK: - 단말 알림 처리

    private func handle(_ note: StatusNotification) {
        switch note {
        case let .messagePart(kind, fromId, number, part, parts, units):
            // 단말이 받은 중앙·동료 메시지를 조각으로 올려 준다. 다 모이면 목록에 넣는다.
            let key = "\(fromId)-\(number)"
            guard parts > 0, !doneKeys.contains(key) else { return }
            partial[key, default: [:]][part] = units
            guard let got = partial[key], got.count == parts else { return }
            let all = (0..<parts).flatMap { got[$0] ?? [] }
            partial[key] = nil
            doneKeys.append(key)
            if doneKeys.count > 20 { doneKeys.removeFirst() }
            let text = String(utf16CodeUnits: all, count: all.count)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                messages.insert(SquadMessage(direction: .incoming, kind: kind,
                                             fromId: fromId, text: text, time: Date()), at: 0)
            }
        case let .event(fromId, event, bearing):
            let label = eventLabel(event)
            messages.insert(SquadMessage(direction: .incoming, kind: .event,
                                         fromId: fromId, text: label, time: Date()), at: 0)
            if event == .enemyFire || event == .enemyHold { updatePeerBearing(fromId: fromId, bearing: Double(bearing)) }
        case let .deliveryAck(_, reportNumber):
            lastDeliveryNumber = Int(reportNumber)
        case let .peerState(fromId, _, band, lat, lon, bearing):
            upsertPeer(id: fromId,
                       coord: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                       bearing: bearing == 0 ? nil : Double(bearing),
                       band: band)
        }
    }

    private func eventLabel(_ e: BLEProtocol.Event) -> String {
        switch e {
        case .ok: return "이상 없음"
        case .sos: return "긴급 구조"
        case .enemyFire: return "적 발견 · 사격 개시"
        case .enemyHold: return "적 발견 · 사격 금지"
        case .ack: return "수신 확인"
        case .correction: return "정정"
        case .none: return "-"
        }
    }

    // MARK: - 동료 목록 갱신

    private func upsertPeer(id: UInt8, coord: CLLocationCoordinate2D?, bearing: Double?, band: Int) {
        if let i = peers.firstIndex(where: { $0.id == id }) {
            if let c = coord { peers[i].coordinate = c }
            peers[i].enemyBearingDeg = bearing
            peers[i].distanceBand = band
            peers[i].lastSeen = Date()
        } else {
            peers.append(Peer(id: id, coordinate: coord, enemyBearingDeg: bearing,
                              distanceBand: band, lastSeen: Date()))
        }
    }

    private func updatePeerBearing(fromId: UInt8, bearing: Double) {
        if let i = peers.firstIndex(where: { $0.id == fromId }) {
            peers[i].enemyBearingDeg = bearing
        }
    }

    // MARK: - 열쇠 로더

    func loadSquadKey(_ key: String) {
        _ = KeychainStore.saveSquadKey(key)
        squadKeyLoaded = KeychainStore.loadSquadKey() != nil
        // TODO: 보안 연결(LESC)로 이 열쇠를 자기 단말에 실제 장전(주입)한다.
        //       펌웨어에 '열쇠 장전' 캐릭터리스틱이 생기면 여기서 write.
    }

    func clearSquadKey() {
        KeychainStore.delete()
        squadKeyLoaded = false
    }
}
