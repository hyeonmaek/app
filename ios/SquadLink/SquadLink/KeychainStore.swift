//
//  KeychainStore.swift
//  SquadLink
//
//  분대 공용 열쇠(문자열)를 아이폰 Keychain에 보관한다.
//  왜 Keychain인가? 앱 저장소(UserDefaults)와 달리 암호화되어 저장되고,
//  다른 앱이 읽지 못한다. 군용 키 로더의 "열쇠는 기기 밖으로 새지 않는다" 원칙과 맞다.
//
//  ※ 여기서는 "보관"까지만 한다. 이 열쇠를 실제로 단말에 장전(LESC 연결로 주입)하는
//    부분은 펌웨어 GATT가 생긴 뒤에 붙인다(KeyLoaderView 의 TODO).
//

import Foundation
import Security

enum KeychainStore {
    private static let service = "com.d4d.squadlink.squadkey"
    private static let account = "current"

    /// 분대 열쇠 저장(있으면 덮어씀).
    @discardableResult
    static func saveSquadKey(_ key: String) -> Bool {
        guard let data = key.data(using: .utf8) else { return false }
        // 기존 것 제거 후 새로 추가 (중복 방지).
        delete()
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            // 기기가 잠금 해제된 상태에서만 접근(이 기기에서만, 백업으로 안 나감).
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    /// 저장된 분대 열쇠 읽기.
    static func loadSquadKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// 열쇠 삭제(탈취 대비 재장전 등).
    @discardableResult
    static func delete() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
