//
//  SquadLinkApp.swift
//  SquadLink
//
//  소부대 오프라인 전술 C2 보조 앱 (D4D × EDTH SEOUL 2026, 트랙 T4-1).
//  이 앱은 상황 인식·지휘통제 "보조"다 — 겨누는 것은 단말이고, 폰은 GPS·메시지·지도용.
//

import SwiftUI

@main
struct SquadLinkApp: App {
    @StateObject private var app = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(app)
        }
    }
}
