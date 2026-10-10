//
//  MessageListView.swift
//  SquadLink
//
//  메시지 타임라인(받은·보낸). 오른쪽 위 작성 버튼으로 새 메시지 창을 연다.
//

import SwiftUI

struct MessageListView: View {
    @EnvironmentObject var app: AppState
    @State private var composing = false
    @State private var toast: String?
    @State private var sentCount = 0

    var body: some View {
        NavigationStack {
            Group {
                if app.messages.isEmpty {
                    ContentUnavailableView("메시지 없음",
                                           systemImage: "bubble.left.and.bubble.right",
                                           description: Text("동료·중앙 메시지와 이벤트가 여기에 쌓입니다."))
                } else {
                    List(app.messages) { msg in
                        MessageRow(msg: msg) { app.ack(msg) }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: app.messages.map(\.id))
            .navigationTitle("메시지")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { composing = true } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .accessibilityLabel("새 메시지")
                }
            }
            .sheet(isPresented: $composing) {
                ComposeSheet { t in
                    sentCount += 1
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { toast = t }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                        withAnimation(.easeInOut(duration: 0.3)) { toast = nil }
                    }
                }
            }
            .overlay(alignment: .top) {
                if let t = toast {
                    Label(t, systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.regularMaterial, in: Capsule())
                        .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
                        .padding(.top, 4)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .sensoryFeedback(.success, trigger: sentCount)
        }
    }
}

private struct MessageRow: View {
    let msg: SquadMessage
    let onAck: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(tint)
                Text(header)
                    .font(.subheadline).bold()
                Spacer()
                Text(msg.time, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(msg.text)
                .font(.body)

            // 중앙에서 내려온 메시지만 수신 확인(S1) 노출.
            if msg.direction == .incoming && msg.kind == .centerMessage {
                Button(action: onAck) {
                    Label(msg.acked ? "확인됨" : "확인",
                          systemImage: msg.acked ? "checkmark.circle.fill" : "checkmark.circle")
                }
                .font(.caption)
                .buttonStyle(.bordered)
                .disabled(msg.acked)
                .tint(msg.acked ? .green : .accentColor)
            }
        }
        .padding(.vertical, 2)
    }

    private var header: String {
        let who = msg.direction == .outgoing ? "나 → \(msg.kind == .centerMessage ? "중앙" : "동료")"
                                             : msg.callSign
        switch msg.kind {
        case .event:         return "\(who) · 이벤트"
        case .centerMessage: return "\(who)"
        case .deliveryAck:   return "\(who) · 전달확인"
        default:             return who
        }
    }

    private var icon: String {
        switch msg.kind {
        case .event:         return "exclamationmark.triangle.fill"
        case .centerMessage: return "building.columns.fill"
        case .deliveryAck:   return "checkmark.seal.fill"
        default:             return msg.direction == .outgoing ? "arrow.up.circle.fill" : "person.fill"
        }
    }

    private var tint: Color {
        switch msg.kind {
        case .event:         return .red
        case .centerMessage: return .blue
        case .deliveryAck:   return .green
        default:             return .secondary
        }
    }
}

#Preview {
    MessageListView().environmentObject(AppState())
}
