//
//  LocationManager.swift
//  SquadLink
//
//  CoreLocation으로 폰 GPS를 받는다. 받은 위치는 2초마다 단말에 write 된다
//  (실제 write 주기는 AppState의 타이머가 돌린다. 여기선 "최신 위치"만 들고 있음).
//
//  설계 원칙: 폰은 '위치 공급'만 한다. 폰 나침반(방향)은 쓰지 않는다 — 겨누는 건 단말.
//

import Foundation
import CoreLocation
import Combine

final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    /// 가장 최근 위치. UI 표시와 단말 write에 공용.
    @Published var lastLocation: CLLocation?
    @Published var authStatus: CLAuthorizationStatus = .notDetermined

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = kCLDistanceFilterNone
    }

    /// 권한 요청 + 위치 갱신 시작.
    func start() {
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    func stop() {
        manager.stopUpdatingLocation()
    }

    // MARK: CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authStatus = manager.authorizationStatus
        if authStatus == .authorizedWhenInUse || authStatus == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        lastLocation = loc
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // 실내 등에서 흔함. 조용히 무시하고 마지막 위치를 유지한다.
    }
}
