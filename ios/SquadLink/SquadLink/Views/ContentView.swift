//
//  ContentView.swift
//  SquadLink
//
//  탭 3개: 연결 · 메시지 · 지도.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var app: AppState
    @State private var tab = 0

    var body: some View {
        TabView(selection: $tab) {
            ConnectionView()
                .tabItem { Label("연결", systemImage: "antenna.radiowaves.left.and.right") }
                .tag(0)
            MessageListView()
                .tabItem { Label("메시지", systemImage: "bubble.left.and.bubble.right") }
                .badge(app.unread)
                .tag(1)
            MapView()
                .tabItem { Label("지도", systemImage: "map") }
                .tag(2)
        }
        // 메시지 탭을 보고 있으면 안 읽음 수를 비운다
        .onChange(of: tab) { _, t in if t == 1 { app.unread = 0 } }
        .onChange(of: app.unread) { _, n in if tab == 1 && n > 0 { app.unread = 0 } }
    }
}

/// 여러 화면 상단에 공통으로 쓰는 상태 배너.
struct StatusBanner: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(app.link.label)
                .font(.subheadline).bold()
            Spacer()
            Text(app.myCallSign)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.thinMaterial)
    }

    private var color: Color {
        switch app.link {
        case .connected: return .green
        case .bluetoothOff: return .red
        default:         return .gray
        }
    }
}

#Preview {
    ContentView().environmentObject(AppState())
}
