//
//  MessageComposeView.swift
//  SquadLink
//
//  새 메시지 작성 창. 메시지 탭 오른쪽 위 작성 버튼으로 아래에서 올라온다(메일·메시지 앱과 같은 배치).
//  왼쪽 위 취소, 오른쪽 위 보내기. Form이 키보드 높이만큼 알아서 비켜 준다.
//

import SwiftUI

struct ComposeSheet: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var toCenter = false
    @FocusState private var focused: Bool
    var onSent: (String) -> Void = { _ in }

    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("보낼 곳", selection: $toCenter) {
                        Text("분대").tag(false)
                        Text("중앙").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                } footer: {
                    Text(toCenter
                         ? "중앙 보고 대상입니다. 기지국이 인터넷을 잠깐 켜 1건 올립니다."
                         : "분대 단말에만 방송됩니다. 인터넷을 쓰지 않습니다.")
                }

                Section {
                    TextField("메시지", text: $text, axis: .vertical)
                        .lineLimit(5...12)
                        .focused($focused)
                        .submitLabel(.return)
                }

                if app.link != .connected {
                    Section {
                        Label("단말에 연결되어야 보낼 수 있습니다", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("새 메시지")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("보내기") {
                        app.send(text: trimmed, toCenter: toCenter)
                        onSent(toCenter ? "중앙 보고 대상으로 보냄" : "\(app.myCallSign) → 분대에 방송됨")
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(trimmed.isEmpty || app.link != .connected)
                }
            }
            .task { focused = true }
        }
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    ComposeSheet().environmentObject(AppState())
}
