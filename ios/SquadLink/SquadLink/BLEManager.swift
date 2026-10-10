//
//  BLEManager.swift
//  SquadLink
//
//  폰이 '중앙 역할(CBCentralManager)'이 되어 자기 단말(주변기기)에 연결한다.
//  흐름: 블루투스 켜짐 확인 → 우리 서비스 UUID로 스캔 → 발견하면 연결 →
//        서비스/캐릭터리스틱 발견 → statusNotify 구독 → 준비 완료.
//
//  LESC 페어링(6자리 숫자)은 iOS가 '암호화가 필요한 캐릭터리스틱'을 읽거나 쓸 때
//  시스템이 자동으로 팝업을 띄워 처리한다(앱이 직접 숫자 UI를 그리지 않음).
//  → 펌웨어에서 캐릭터리스틱에 '암호화 필요' 권한을 걸면 OS 페어링이 뜬다.
//

import Foundation
import CoreBluetooth
import Combine

final class BLEManager: NSObject, ObservableObject {

    // 상위(AppState)가 구독할 수 있도록 상태/수신을 퍼블리시.
    @Published var state: LinkState = .idle
    @Published var discoveredName: String?        // 연결된 단말 이름(SQUAD-E1 등)
    @Published var found: [FoundDevice] = []       // 스캔으로 찾은 단말 목록(사용자가 골라 연결)
    @Published var lastError: String?              // 마지막으로 끊긴/실패한 이유(화면 안내용)

    struct FoundDevice: Identifiable, Equatable {
        let id: UUID
        let name: String
        let peripheral: CBPeripheral
        var rssi: Int
        static func == (a: FoundDevice, b: FoundDevice) -> Bool { a.id == b.id && a.rssi == b.rssi && a.name == b.name }
    }

    /// statusNotify로 올라온 메시지를 상위로 넘기는 콜백.
    var onStatus: ((StatusNotification) -> Void)?

    private var central: CBCentralManager!
    private var terminal: CBPeripheral?          // 내 단말
    private var gpsChar: CBCharacteristic?
    private var msgChar: CBCharacteristic?
    private var statusChar: CBCharacteristic?

    private var wantScan = false                 // 블루투스가 켜지면 스캔 시작할지

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: .main)
    }

    // MARK: - 외부에서 부르는 동작

    /// 단말 찾기 시작(목록만 채움. 연결은 사용자가 골라서).
    func startScan() {
        wantScan = true
        found = []
        guard central.state == .poweredOn else {
            state = central.state == .poweredOff ? .bluetoothOff : .idle
            return
        }
        state = .scanning
        central.scanForPeripherals(withServices: [BLEProtocol.serviceUUID],
                                   options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
    }

    /// 사용자가 목록에서 고른 단말에 연결(페어링은 OS가 6자리로 유도).
    func connect(to peripheral: CBPeripheral) {
        lastError = nil
        wantScan = false
        central.stopScan()
        terminal = peripheral
        discoveredName = peripheral.name ?? "단말"
        state = .connecting
        central.connect(peripheral, options: nil)
    }

    func stop() {
        wantScan = false
        central.stopScan()
        if let t = terminal { central.cancelPeripheralConnection(t) }
        terminal = nil
        gpsChar = nil; msgChar = nil; statusChar = nil
        if state != .bluetoothOff { state = .idle }
    }

    /// 폰 → 단말: 최신 GPS write.
    func writeGPS(lat: Double, lon: Double, accuracyM: Double, ageSeconds: Double) {
        guard let t = terminal, let c = gpsChar else { return }
        let data = BLEProtocol.encodeGPS(lat: lat, lon: lon, accuracyM: accuracyM, ageSeconds: ageSeconds)
        // 응답 없는 write 지원 여부에 따라 선택(GPS는 자주 갱신 → 응답 없는 쪽 선호).
        let type: CBCharacteristicWriteType =
            c.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse
        t.writeValue(data, for: c, type: type)
    }

    /// 폰 → 단말: 메시지 write.
    func writeMessage(target: BLEProtocol.Target, text: String) {
        guard let t = terminal, let c = msgChar else { return }
        let data = BLEProtocol.encodeMessage(target: target, text: text)
        t.writeValue(data, for: c, type: .withResponse)
    }

    /// 폰 → 단말: 수신 확인(S1) — 이벤트 ACK를 메시지 통로로 간단히 흘려보낸다(초안).
    func sendAck(messageNumber: UInt8) {
        guard let t = terminal, let c = msgChar else { return }
        // ACK 전용 바이트: [version=1][target=center][0xFF 표식][msgNo]
        var d = Data([1, BLEProtocol.Target.center.rawValue, 0xFF, messageNumber])
        t.writeValue(d, for: c, type: .withResponse)
        d.removeAll()
    }
}

// MARK: - CBCentralManagerDelegate

extension BLEManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            if wantScan { startScan() } else { state = .idle }
        case .poweredOff:
            state = .bluetoothOff
        default:
            state = .idle
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any],
                        rssi RSSI: NSNumber) {
        // 우리 서비스 UUID로만 스캔하므로 이 콜백에 오면 단말 후보. 목록에만 추가(자동연결 X).
        let name = (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? peripheral.name ?? "단말"
        let r = RSSI.intValue == 127 ? -100 : RSSI.intValue
        if let i = found.firstIndex(where: { $0.id == peripheral.identifier }) {
            if abs(found[i].rssi - r) >= 4 { found[i].rssi = r }   // 너무 자주 갱신하지 않게
        } else {
            found.append(FoundDevice(id: peripheral.identifier, name: name, peripheral: peripheral, rssi: r))
            found.sort { $0.name < $1.name }
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        state = .pairing   // 암호화 캐릭터리스틱 접근 시 OS가 6자리 페어링을 띄울 수 있음
        peripheral.discoverServices([BLEProtocol.serviceUUID])
    }

    func centralManager(_ central: CBCentralManager,
                        didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {
        let wasPairing = (state == .pairing)
        gpsChar = nil; msgChar = nil; statusChar = nil
        if let e = error, (e as NSError).domain == CBErrorDomain,
           (e as NSError).code == CBError.peerRemovedPairingInformation.rawValue {
            lastError = Self.explain(e)
        } else if wasPairing {
            lastError = "페어링 번호가 틀렸습니다. 단말 화면의 6자리를 다시 확인하고 연결하세요."
        } else if state != .connected, let e = error {
            lastError = Self.explain(e)
        }
        if wantScan {
            // 끊기면 다시 찾기(실전에서 순간 끊김 대비).
            startScan()
        } else {
            state = .idle
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didFailToConnect peripheral: CBPeripheral,
                        error: Error?) {
        if let e = error { lastError = Self.explain(e) }
        if wantScan { startScan() } else { state = .idle }
    }

    /// 아이폰이 옛 페어링 열쇠를 들고 있는 경우 등, 사용자에게 할 일을 알려 준다.
    static func explain(_ e: Error) -> String {
        let ns = e as NSError
        if ns.domain == CBErrorDomain,
           ns.code == CBError.peerRemovedPairingInformation.rawValue || ns.code == CBError.encryptionTimedOut.rawValue {
            return "단말이 예전 페어링을 지웠습니다. 설정 > 블루투스에서 이 단말을 '이 기기 지우기' 후 다시 연결하세요."
        }
        if ns.domain == CBATTErrorDomain,
           ns.code == CBATTError.insufficientAuthentication.rawValue || ns.code == CBATTError.insufficientEncryption.rawValue {
            return "페어링 번호가 맞지 않았습니다. 다시 연결해 단말 화면의 6자리를 입력하세요."
        }
        return "연결이 끊겼습니다: \(e.localizedDescription)"
    }
}

// MARK: - CBPeripheralDelegate

extension BLEManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for s in services where s.uuid == BLEProtocol.serviceUUID {
            peripheral.discoverCharacteristics(
                [BLEProtocol.gpsWriteUUID, BLEProtocol.msgWriteUUID, BLEProtocol.statusNotifyUUID],
                for: s)
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        guard let chars = service.characteristics else { return }
        for c in chars {
            switch c.uuid {
            case BLEProtocol.gpsWriteUUID:    gpsChar = c
            case BLEProtocol.msgWriteUUID:    msgChar = c
            case BLEProtocol.statusNotifyUUID:
                statusChar = c
                peripheral.setNotifyValue(true, for: c)   // 단말이 올려줄 알림 구독
            default: break
            }
        }
        // 여기선 아직 "연결됨" 아님. 상태 알림 구독(암호화 필요) 시 OS가 6자리 입력창을 띄우고,
        // 페어링이 끝나 구독이 성공하면 그때 연결됨(didUpdateNotificationStateFor).
        if msgChar != nil && statusChar != nil { state = .pairing }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateNotificationStateFor characteristic: CBCharacteristic,
                    error: Error?) {
        guard characteristic.uuid == BLEProtocol.statusNotifyUUID else { return }
        if error == nil && characteristic.isNotifying {
            state = .connected          // 페어링 성공 → 사용 가능
        } else {
            state = .pairing            // 번호 틀림/취소 → 다시 시도 필요
            if let e = error { lastError = Self.explain(e) }
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        guard characteristic.uuid == BLEProtocol.statusNotifyUUID,
              let data = characteristic.value,
              let note = BLEProtocol.decodeStatus(data) else { return }
        onStatus?(note)
    }
}
