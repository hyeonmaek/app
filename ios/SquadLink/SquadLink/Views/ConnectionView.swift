//
//  ConnectionView.swift
//  SquadLink
//
//  연결 화면. 단말을 찾아 목록에서 골라 연결하고, 단말 화면의 6자리 번호로 페어링한다.
//  상태마다 큰 아이콘이 바뀌고(레이더 → 스피너 → 자물쇠 → 체크), 목록 카드는 부드럽게 등장한다.
//

import SwiftUI

struct ConnectionView: View {
    @EnvironmentObject var app: AppState
    @State private var shakes = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    HeroCard()
                        .modifier(Shake(animatableData: CGFloat(shakes)))
                        .onChange(of: app.lastError) { _, e in
                            if e != nil { withAnimation(.linear(duration: 0.45)) { shakes += 1 } }
                        }
                    if let err = app.lastError, app.link != .connected {
                        Label(err, systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    if app.link == .connected {
                        ConnectedCard()
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else {
                        DeviceList()
                    }
                    if let n = app.lastDeliveryNumber {
                        Label("#\(n) 중앙 전달됨", systemImage: "checkmark.seal.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.green)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .animation(.spring(response: 0.45, dampingFraction: 0.85), value: app.link)
                .animation(.spring(response: 0.45, dampingFraction: 0.85), value: app.found)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("현맥")
            .sensoryFeedback(.success, trigger: app.link == .connected)
            .sensoryFeedback(.error, trigger: app.lastError)
        }
    }
}

/// 실패 시 좌우로 흔드는 효과(아이폰 잠금화면 암호 틀림처럼).
private struct Shake: GeometryEffect {
    var animatableData: CGFloat
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 10 * sin(animatableData * .pi * 6), y: 0))
    }
}

// MARK: - 상단 상태 카드

private struct HeroCard: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                if app.link == .scanning { RadarRings() }
                Circle()
                    .fill(tint.opacity(0.14))
                    .frame(width: 104, height: 104)
                icon
                    .id(app.link)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
            .frame(height: 170)

            Text(title)
                .font(.title2.weight(.bold))
                .contentTransition(.opacity)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .contentTransition(.opacity)

            if app.link == .idle || app.link == .bluetoothOff {
                Button {
                    app.scan()
                } label: {
                    Text("단말 찾기")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .padding(.top, 4)
                .transition(.opacity)
            } else if app.link == .scanning {
                Button("다시 찾기") { app.scan() }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .transition(.opacity)
            } else if app.link == .pairing || app.link == .connecting {
                Button("취소", role: .cancel) { app.disconnect() }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .transition(.opacity)
            }
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    @ViewBuilder private var icon: some View {
        switch app.link {
        case .idle:
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(.secondary)
        case .bluetoothOff:
            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(.red)
        case .scanning:
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(.tint)
                .symbolEffect(.variableColor.iterative.reversing)
        case .connecting:
            ProgressView()
                .controlSize(.large)
        case .pairing:
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 48, weight: .medium))
                .foregroundStyle(.orange)
                .symbolEffect(.pulse)
        case .connected:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56, weight: .medium))
                .foregroundStyle(.green)
                .symbolEffect(.bounce, value: app.link)
        }
    }

    private var tint: Color {
        switch app.link {
        case .connected: return .green
        case .pairing: return .orange
        case .bluetoothOff: return .red
        case .idle: return .gray
        default: return .accentColor
        }
    }

    private var name: String { app.ble.discoveredName ?? "단말" }

    private var title: String {
        switch app.link {
        case .idle: return "단말 연결"
        case .bluetoothOff: return "블루투스 꺼짐"
        case .scanning: return "단말 찾는 중"
        case .connecting: return "연결 중"
        case .pairing: return "페어링 번호 입력"
        case .connected: return "\(app.myCallSign) 연결됨"
        }
    }

    private var subtitle: String {
        switch app.link {
        case .idle: return "근처 분대 단말을 찾아 내 폰과 연결합니다."
        case .bluetoothOff: return "설정에서 블루투스를 켜 주세요."
        case .scanning: return "연결할 단말을 아래 목록에서 고르세요."
        case .connecting: return "\(name)에 연결하고 있습니다."
        case .pairing: return "\(name) 화면에 뜬 6자리 번호를\n아이폰 입력창에 입력하세요."
        case .connected: return "보낸 메시지는 \(app.myCallSign)을 거쳐 분대에 방송됩니다."
        }
    }
}

/// 찾는 중일 때 퍼져 나가는 원(레이더).
private struct RadarRings: View {
    @State private var go = false
    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .stroke(Color.accentColor.opacity(0.45), lineWidth: 2)
                    .frame(width: 104, height: 104)
                    .scaleEffect(go ? 1.7 : 1)
                    .opacity(go ? 0 : 0.9)
                    .animation(.easeOut(duration: 2.1).repeatForever(autoreverses: false).delay(Double(i) * 0.7), value: go)
            }
        }
        .onAppear { go = true }
    }
}

// MARK: - 찾은 단말 목록

private struct DeviceList: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !app.found.isEmpty {
                Text("찾은 단말")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 6)
                ForEach(app.found) { d in
                    Button {
                        app.connect(to: d)
                    } label: {
                        DeviceRow(device: d, busy: busy(d))
                    }
                    .buttonStyle(PressableStyle())
                    .disabled(app.link == .connecting || app.link == .pairing)
                    .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity),
                                            removal: .opacity))
                }
            } else if app.link == .scanning {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("주변 단말을 찾고 있어요…").foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .transition(.opacity)
            }
        }
    }

    private func busy(_ d: BLEManager.FoundDevice) -> Bool {
        (app.link == .connecting || app.link == .pairing) && app.ble.discoveredName == d.name
    }
}

private struct DeviceRow: View {
    let device: BLEManager.FoundDevice
    let busy: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(Color.accentColor.gradient, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(AppState.callSign(from: device.name))
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(device.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            SignalBars(rssi: device.rssi)
            if busy {
                ProgressView().padding(.leading, 4)
            } else {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .contentShape(Rectangle())
    }
}

private struct SignalBars: View {
    let rssi: Int
    private var level: Int { rssi > -55 ? 4 : rssi > -67 ? 3 : rssi > -78 ? 2 : 1 }
    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<4, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(i < level ? Color.accentColor : Color.secondary.opacity(0.25))
                    .frame(width: 4, height: CGFloat(5 + i * 4))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: level)
    }
}

/// 누르면 살짝 작아지는 카드 버튼.
private struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - 연결됨 카드

private struct ConnectedCard: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        VStack(spacing: 0) {
            row(icon: "dot.radiowaves.left.and.right", color: .accentColor,
                title: "연결된 단말", value: app.ble.discoveredName ?? "-")
            Divider().padding(.leading, 58)
            Button(role: .destructive) {
                app.disconnect()
            } label: {
                HStack {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 30)
                    Text("연결 끊기")
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
            }
        }
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func row(icon: String, color: Color, title: String, value: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(color.gradient, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            Text(title)
            Spacer()
            Text(value).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }
}

#Preview {
    ConnectionView().environmentObject(AppState())
}
