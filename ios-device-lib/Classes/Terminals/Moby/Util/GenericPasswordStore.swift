//
//  GenericPasswordStore.swift
//  ios-device-lib
//

import Foundation
import CryptoKit
import Security

struct GenericPasswordStore {
    
    /// Stores a CryptoKit key in the keychain as a generic password.
    @available(iOS 13.0, *)
    func storeKey<T: GenericPasswordConvertible>(_ key: T, account: String) throws {
        // Treat the key data as a generic password.
        
        let query = [kSecClass: kSecClassGenericPassword,
                     kSecAttrAccount: account,
                     kSecAttrAccessible: kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
                     kSecUseDataProtectionKeychain: true,
                     kSecValueData: key.rawRepresentation] as [String: Any]
        
        // Add the key data.
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeyStoreError("Unable to store item: \(status.message)")
        }
    }
    
    func storeKey(key: String, account: String) throws {
        guard let data = Data(from: key) else {
            throw KeyStoreError("Key is nil. Unable to store item ")
        }
        
        let query = [kSecClass as String: kSecClassGenericPassword as String,
                     kSecAttrAccount as String: account,
                     kSecAttrAccessible as String: kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
                     kSecValueData as String: data] as [String: Any]
        
        // Add the key data.
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            if #available(iOS 11.3, *) {
                throw KeyStoreError("Unable to store item: \(status.message)")
            } else {
                throw KeyStoreError("Unable to store item:")
            }
        }
    }
    
    
    /// Reads a CryptoKit key from the keychain as a generic password.
    @available(iOS 13.0, *)
    func readKey<T: GenericPasswordConvertible>(account: String) throws -> T? {
        // Seek a generic password with the given account.
        let query = [kSecClass: kSecClassGenericPassword,
                     kSecAttrAccount: account,
                     kSecUseDataProtectionKeychain: true,
                     kSecReturnData: true] as [String: Any]
        
        // Find and cast the result as data.
        var item: CFTypeRef?
        switch SecItemCopyMatching(query as CFDictionary, &item) {
        case errSecSuccess:
            guard let data = item as? Data else { return nil }
            return try T(rawRepresentation: data)  // Convert back to a key.
        case errSecItemNotFound: return nil
        case let status:
            throw KeyStoreError("Keychain read failed: \(status.message)")
        }
    }
    
    func readKey(account: String) throws -> String? {
        
        let query = [kSecClass: kSecClassGenericPassword,
                     kSecAttrAccount: account,
                     kSecReturnData: true] as [String: Any]
        // Find and cast the result as data.
        var item: CFTypeRef?
        
        switch SecItemCopyMatching(query as CFDictionary, &item) {
        case errSecSuccess:
            guard let data = item as? Data else { return nil }
            return data.toString() // Convert back to a key.
        case errSecItemNotFound: return nil
        case let status: if #available(iOS 11.3, *) {
            throw KeyStoreError("Keychain read failed: \(status.message)")
        } else {
            throw KeyStoreError("Keychain read failed")
        }
        }
    }
    
    /// Stores a key in the keychain and then reads it back.
    @available(iOS 13.0, *)
    func roundTrip<T: GenericPasswordConvertible>(_ key: T, account: String) throws -> T {
        
        // An account name for the key in the keychain.
        let account = account
        
        // Start fresh.
        try deleteKey(account: account)
        
        // Store and read it back.
        try storeKey(key, account: account)
        guard let key: T = try readKey(account: account) else {
            throw KeyStoreError("Failed to locate stored key.")
        }
        return key
    }
    
    /// Removes any existing key with the given account.
    @available(iOS 13.0, *)
    func deleteKey(account: String) throws {
        let query = [kSecClass: kSecClassGenericPassword,
                     kSecUseDataProtectionKeychain: true,
                     kSecAttrAccount: account] as [String: Any]
        switch SecItemDelete(query as CFDictionary) {
        case errSecItemNotFound, errSecSuccess: break // Okay to ignore
        case let status:
            throw KeyStoreError("Unexpected deletion error: \(status.message)")
        }
    }
    
    func deleteKeyForPreviousOSVersion(account: String) throws {
        let query = [kSecClass: kSecClassGenericPassword,
                     kSecAttrAccount: account] as [String: Any]
        switch SecItemDelete(query as CFDictionary) {
        case errSecItemNotFound, errSecSuccess: break // Okay to ignore
        case let status:
            if #available(iOS 11.3, *) {
                throw KeyStoreError("Unexpected deletion error: \(status.message)")
            } else {
                throw KeyStoreError("Unexpected deletion error")
            }
        }
    }
}

protocol GenericPasswordConvertible: CustomStringConvertible {
    init<D>(rawRepresentation data: D) throws where D: ContiguousBytes
    
    var rawRepresentation: Data { get }
}

extension GenericPasswordConvertible {
    public var description: String {
        return self.rawRepresentation.withUnsafeBytes { bytes in
            return "Key representation contains \(bytes.count) bytes."
        }
    }
}

@available(iOS 13.0, *)
extension SymmetricKey: GenericPasswordConvertible {
    init<D>(rawRepresentation data: D) throws where D: ContiguousBytes {
        self.init(data: data)
    }
    
    var rawRepresentation: Data {
        return dataRepresentation  // Contiguous bytes repackaged as a Data instance.
    }
}

extension ContiguousBytes {
    /// A Data instance created safely from the contiguous bytes without making any copies.
    var dataRepresentation: Data {
        return self.withUnsafeBytes { bytes in
            let cfdata = CFDataCreateWithBytesNoCopy(nil, bytes.baseAddress?.assumingMemoryBound(to: UInt8.self), bytes.count, kCFAllocatorNull)
            return ((cfdata as NSData?) as Data?) ?? Data()
        }
    }
}

/// An error we can throw when something goes wrong.
struct KeyStoreError: Error, CustomStringConvertible {
    var message: String
    
    init(_ message: String) {
        self.message = message
    }
    
    public var description: String {
        return message
    }
}

@available(iOS 11.3, *)
extension OSStatus {
    var message: String {
        return (SecCopyErrorMessageString(self, nil) as String?) ?? String(self)
    }
}

extension Data {
    init?(from value: String) {
        guard let data = value.data(using: String.Encoding.utf8, allowLossyConversion: false) else {
            return nil
        }
        
        self = data
    }
    
    func toString() -> String {
        return String(data: self, encoding: String.Encoding.utf8) ?? ""
    }
}
