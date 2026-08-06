//
//  SafFileManager.swift
//  ios-device-lib
//

import Foundation
import CryptoKit

struct SafFileManager {
    static private let accountKey = "com.testing.encryptdata"
    static private let fileName = "transaction.txt"
    
    static private func randomString(length: Int) -> String {
      let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789/@=-"
      return String((0..<length).map{ _ in letters.randomElement()! })
    }
    
    static private func getURL() -> URL? {
        guard let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let dir = url.appendingPathComponent("SafTransactions", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    
    static func store<T: Encodable>(_ object: T) throws {
        guard let url = getURL()?.appendingPathComponent(fileName, isDirectory: false) else { return }
        
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(object)
            
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
            
            if #available(iOS 13.0, *) {
                var symmetricKey: SymmetricKey
                
                if let key: SymmetricKey = try GenericPasswordStore().readKey(account: accountKey) {
                    symmetricKey = key
                } else {
                    symmetricKey = SymmetricKey(size: .bits256)
                    try GenericPasswordStore().storeKey(symmetricKey, account: accountKey)
                }
                
                let sealedBox = try ChaChaPoly.seal(data, using: symmetricKey).combined
                FileManager.default.createFile(atPath: url.path, contents: sealedBox, attributes: nil)
            } else {
                var privateKey: String
                
                if let key = try GenericPasswordStore().readKey(account: accountKey) {
                    privateKey = key
                } else {
                    privateKey = randomString(length: 32)
                    
                    try GenericPasswordStore().storeKey(key: privateKey, account: accountKey)
                }
                
                let aes = try AES(keyString: privateKey)
                let encryptedData: Data = try aes.encrypt(data)
                
                FileManager.default.createFile(atPath: url.path, contents: encryptedData, attributes: nil)
            }
        } catch let error {
            throw SafFileManagerError.store(message: error.localizedDescription)
        }
    }

    static func retrieve<T: Codable>(type: T.Type) throws -> T? {
        guard let url = getURL()?.appendingPathComponent(fileName, isDirectory: false) else { return nil }
      
        if let data = FileManager.default.contents(atPath: url.path), FileManager.default.fileExists(atPath: url.path) {
            do {
                if #available(iOS 13.0, *) {
                    guard let symmetricKey: SymmetricKey = try GenericPasswordStore().readKey(account: accountKey) else {
                        // check for private key
                        guard let privateKey = try GenericPasswordStore().readKey(account: accountKey) else { return nil }
                        
                        // backup currentdata
                        guard let currentData: T? = try dycryptDataModel(data: data, privateKey: privateKey) else { return nil }
                        
                        // update data with new symmetricKey and remove old private key
                        keyAndDataMigration(data: currentData)
                        
                        return try dycryptDataModel(data: data, privateKey: privateKey)
                    }
                    
                    return try dycryptDataModel(data: data, symmetricKey: symmetricKey)
                } else {
                    guard let privateKey = try GenericPasswordStore().readKey(account: accountKey) else { return nil }
                    
                    return try dycryptDataModel(data: data, privateKey: privateKey)
                }
                
            } catch {
                throw SafFileManagerError.retrieve(message: error.localizedDescription)
            }
        } else {
            throw SafFileManagerError.retrieve(message: "Data not exist or file not exist at path")
        
        }
    }
    
    @available(iOS 13.0, *)
    static private func dycryptDataModel<T: Decodable>(data: Data, symmetricKey: SymmetricKey) throws -> T? {
        do {
            if let sealedBox1 = try? ChaChaPoly.SealedBox(combined: data) {
                guard let decryptedData = try? ChaChaPoly.open(sealedBox1, using: symmetricKey) else {
                    throw KeyStoreError("Decryption failed — key or data mismatch")
                }
                
                let model = try JSONDecoder().decode(T.self, from: decryptedData)
                return model
            } else {
                return nil
            }
        } catch {
            throw KeyStoreError("Data dycryption issue with symmetricKey key")
        }
    }
    
    static private func dycryptDataModel<T: Decodable>(data: Data, privateKey: String) throws -> T? {
        do {
            let aes = try AES(keyString: privateKey)

            let decryptedData = try aes.decrypt(data)
            
            let model = try JSONDecoder().decode(T.self, from: decryptedData)
            
            return model
        } catch {
            throw KeyStoreError("Data dycryption issue with private key")
        }
    }
    
    static func keyAndDataMigration<T: Codable>(data: T) {
        // remove directory data and keychain key
        removeFile()
        
        // store current data with updated symmetricKey
        try? store(data)
    }
    
    /// Remove all files at specified directory
    static func clear() {
        if let url = getURL() {
            do {
                let contents = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [])
                
                for fileUrl in contents {
                    try FileManager.default.removeItem(at: fileUrl)
                }
                
                if #available(iOS 13.0, *) {
                    try GenericPasswordStore().deleteKey(account: accountKey)
                } else {
                    try GenericPasswordStore().deleteKeyForPreviousOSVersion(account: accountKey)
                }
            } catch {
                print(error.localizedDescription)
            }
        }
    }
    
    /// Remove specified file from specified directory
    static func removeFile() {
        if let url = getURL()?.appendingPathComponent(fileName, isDirectory: false) {
            if FileManager.default.fileExists(atPath: url.path) {
                do {
                    try FileManager.default.removeItem(at: url)
                    
                    if #available(iOS 13.0, *) {
                        try GenericPasswordStore().deleteKey(account: accountKey)
                    } else {
                        try GenericPasswordStore().deleteKeyForPreviousOSVersion(account: accountKey)
                    }
                } catch {
                    print(error.localizedDescription)
                }
            }
        }
    }
    
    /// Returns BOOL indicating whether file exists at specified directory with specified file name
   public static func fileExists() -> Bool {
        guard let url = getURL()?.appendingPathComponent(fileName, isDirectory: false) else { return false }
        
        return FileManager.default.fileExists(atPath: url.path)
    }
}

/// An error we can throw when something goes wrong.
enum SafFileManagerError: Error {
    case store(message: String)
    case retrieve(message: String)
}
