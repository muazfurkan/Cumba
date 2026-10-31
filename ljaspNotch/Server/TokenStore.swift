import Foundation
import Security

/// The local server's shared secret: 32 random bytes as hex, kept in the login Keychain
/// (SPEC § 12). Keychain calls block, so use these only off the main thread.
enum TokenStore {
  enum Failure: Error {
    case keychain(OSStatus)
    case randomness(OSStatus)
  }

  private static let service = "io.github.muazfurkan.ljaspnotch.server"
  private static let account = "token"

  static func loadOrCreate() throws(Failure) -> String {
    if let existing = try load() {
      return existing
    }
    return try regenerate()
  }

  /// Replaces the token. Hooks and the extension must be given the new one.
  @discardableResult
  static func regenerate() throws(Failure) -> String {
    let token = try makeToken()
    let data = Data(token.utf8)
    let query = baseQuery()
    let status = SecItemUpdate(
      query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
    if status == errSecItemNotFound {
      var item = query
      item[kSecValueData as String] = data
      item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
      let addStatus = SecItemAdd(item as CFDictionary, nil)
      guard addStatus == errSecSuccess else { throw .keychain(addStatus) }
    } else if status != errSecSuccess {
      throw .keychain(status)
    }
    return token
  }

  private static func load() throws(Failure) -> String? {
    var query = baseQuery()
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne
    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    switch status {
    case errSecSuccess:
      guard let data = result as? Data, let token = String(data: data, encoding: .utf8),
        token.count == 64
      else { return nil }
      return token
    case errSecItemNotFound:
      return nil
    default:
      throw .keychain(status)
    }
  }

  private static func baseQuery() -> [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
    ]
  }

  private static func makeToken() throws(Failure) -> String {
    var bytes = [UInt8](repeating: 0, count: 32)
    let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
    guard status == errSecSuccess else { throw .randomness(status) }
    return bytes.map { String(format: "%02x", $0) }.joined()
  }
}
