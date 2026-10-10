//
//  KeyLoaderView.swift
//  SquadLink
//
//  키 로더. 분대 공용 열쇠(문자열)를 QR로 대면 전달받아 Keychain에 보관한다.
//  "열쇠는 전파로 보내지 않는다"(군용 키 로더 원칙) — 그래서 카메라로 직접 읽는다.
//
//  ※ 시뮬레이터에는 카메라가 없다. 그래서 수동 입력과 '모의 스캔' 버튼도 둔다.
//  ※ 실제로 이 열쇠를 단말에 '장전'(LESC 보안 연결로 주입)하는 부분은 TODO.
//

import SwiftUI
import AVFoundation

struct KeyLoaderView: View {
    @EnvironmentObject var app: AppState
    @State private var showScanner = false
    @State private var manualKey = ""
    @State private var scanError: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                StatusBanner()
                Form {
                    Section("현재 분대 열쇠") {
                        if app.squadKeyLoaded {
                            Label("보관됨 (Keychain, 이 기기 전용)", systemImage: "lock.fill")
                                .foregroundStyle(.green)
                            Button(role: .destructive) {
                                app.clearSquadKey()
                            } label: {
                                Label("열쇠 지우기 (탈취 대비 재장전)", systemImage: "trash")
                            }
                        } else {
                            Label("열쇠 없음", systemImage: "lock.open")
                                .foregroundStyle(.secondary)
                        }
                    }

                    Section("QR로 받기 (대면 전달)") {
                        Button {
                            scanError = nil
                            showScanner = true
                        } label: {
                            Label("QR 스캔 시작", systemImage: "qrcode.viewfinder")
                        }
                        if let e = scanError {
                            Text(e).font(.caption).foregroundStyle(.red)
                        }
                    }

                    Section("수동 입력 / 모의 (시뮬레이터용)") {
                        TextField("열쇠 문자열", text: $manualKey)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        Button("이 값으로 장전") {
                            load(manualKey)
                        }
                        .disabled(manualKey.trimmingCharacters(in: .whitespaces).isEmpty)
                        Button("모의 열쇠로 장전") {
                            load("SQUAD-DEMO-AES128-0123456789ABCDEF")
                        }
                    }

                    Section {
                        Text("장전 뒤, 이 열쇠를 단말에 보안 연결로 주입하는 단계는 펌웨어 GATT가 준비되면 붙입니다(코드 TODO).")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("키 로더")
            .sheet(isPresented: $showScanner) {
                QRScannerView { result in
                    showScanner = false
                    switch result {
                    case .success(let code): load(code)
                    case .failure(let err):  scanError = err
                    }
                }
            }
        }
    }

    private func load(_ raw: String) {
        let key = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        app.loadSquadKey(key)
        manualKey = ""
    }
}

// MARK: - AVFoundation QR 스캐너 (UIKit 래핑)

/// 카메라로 QR을 읽어 문자열 하나를 돌려준다. 시뮬레이터에선 카메라가 없어 실패를 반환.
struct QRScannerView: UIViewControllerRepresentable {
    enum ScanResult { case success(String), failure(String) }
    let onResult: (ScanResult) -> Void

    func makeUIViewController(context: Context) -> QRScannerController {
        let vc = QRScannerController()
        vc.onResult = onResult
        return vc
    }
    func updateUIViewController(_ uiViewController: QRScannerController, context: Context) {}
}

final class QRScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onResult: ((QRScannerView.ScanResult) -> Void)?
    private let session = AVCaptureSession()
    private var delivered = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            // 시뮬레이터/권한없음: 카메라 사용 불가.
            finish(.failure("카메라를 쓸 수 없습니다. 시뮬레이터면 수동 입력을 쓰세요."))
            return
        }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else {
            finish(.failure("카메라 출력 설정 실패")); return
        }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.frame = view.layer.bounds
        preview.videoGravity = .resizeAspectFill
        view.layer.addSublayer(preview)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if session.isRunning { session.stopRunning() }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let str = obj.stringValue else { return }
        finish(.success(str))
    }

    private func finish(_ result: QRScannerView.ScanResult) {
        guard !delivered else { return }
        delivered = true
        if session.isRunning { session.stopRunning() }
        onResult?(result)
    }
}

#Preview {
    KeyLoaderView().environmentObject(AppState())
}
