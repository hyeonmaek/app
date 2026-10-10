//
//  MapView.swift
//  SquadLink
//
//  지도 탭: 화면 전체가 지도. 내 위치(파란 점)와, 위치를 아는 동료·그 동료가 겨눈 적 방향선만 얹는다.
//

import SwiftUI
import MapKit

struct MapView: View {
    @EnvironmentObject var app: AppState
    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)

    var body: some View {
        Map(position: $position) {
            UserAnnotation()
            ForEach(app.peers) { peer in
                if let c = peer.coordinate {
                    Annotation(peer.callSign, coordinate: c) {
                        Circle()
                            .fill(.cyan)
                            .stroke(.white, lineWidth: 2)
                            .frame(width: 14, height: 14)
                    }
                    if let b = peer.enemyBearingDeg {
                        MapPolyline(coordinates: [c, Self.offset(c, bearing: b, meters: 100)])
                            .stroke(.red, style: StrokeStyle(lineWidth: 3, dash: [8, 5]))
                    }
                }
            }
        }
        .mapStyle(.hybrid(elevation: .flat))
        .mapControls {
            MapUserLocationButton()
            MapCompass()
            MapScaleView()
        }
    }

    /// 한 점에서 방위각(진북 기준) 방향으로 meters만큼 간 좌표(짧은 거리 평면 근사).
    static func offset(_ c: CLLocationCoordinate2D, bearing: Double, meters: Double) -> CLLocationCoordinate2D {
        let rad = bearing * .pi / 180
        let dLat = meters * cos(rad) / 111_320
        let dLon = meters * sin(rad) / (111_320 * cos(c.latitude * .pi / 180))
        return CLLocationCoordinate2D(latitude: c.latitude + dLat, longitude: c.longitude + dLon)
    }
}

#Preview {
    MapView().environmentObject(AppState())
}
