//
//  PorticoUtility.swift
//  ios-device-lib
//

import Foundation

public class PorticoUtility {

    private init() {}

    // MARK: - Thread Safety

    /// Dedicated lock protecting all access to `_originalTransactionIdCopy`.
    /// Using NSLock (not objc_sync) so the locking intent is explicit and
    /// the critical section is clearly scoped with lock()/unlock().
    private static let transactionIdLock = NSLock()
    private static var _originalTransactionIdCopy: String?
    public static var originalTransactionIdCopy: String? {
        get {
            transactionIdLock.lock()
            defer { transactionIdLock.unlock() }
            return _originalTransactionIdCopy
        }
        set {
            transactionIdLock.lock()
            defer { transactionIdLock.unlock() }
            _originalTransactionIdCopy = newValue
        }
    }

    // MARK: - Hex ↔ Base64

    public static func encodeHexString(toBase64From hexString: String) -> String {
        var data = Data(capacity: hexString.count / 2)

        var index = hexString.startIndex
        while index < hexString.endIndex {
            let nextIndex = hexString.index(index, offsetBy: 2, limitedBy: hexString.endIndex)
                         ?? hexString.endIndex
            let byteStr = String(hexString[index ..< nextIndex])
            if let byte = UInt8(byteStr, radix: 16) {
                data.append(byte)
            }
            index = nextIndex
        }

        return data.base64EncodedString()
    }

    public static func decodeBase64(toHexStringFrom base64EncodedString: String) -> String {
        guard let data = Data(base64Encoded: base64EncodedString) else { return "" }
        return data.map { String(format: "%02X", $0) }.joined()
    }

    // MARK: - Client Transaction ID
    public static func generateClientTransactionId() -> String {
        let uniqueId = generatedUniqueIdFromDate()
        let uniqueString = "\(uniqueId)"
        print(uniqueString)
        return uniqueString
    }

    public static func generatedUniqueIdFromDate() -> NSNumber {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }
        let currentTime = Int64(Date().timeIntervalSince1970)
        return NSNumber(value: currentTime)
    }

    // MARK: - Original Transaction ID Management
    public static func updateOriginalTransactionIdCopy(_ transactionId: String?) {
        originalTransactionIdCopy = transactionId
    }

    public static func isOriginalTransactionIdValid() -> Bool {
        guard let idString = originalTransactionIdCopy,
              let idInt    = Int(idString) else { return false }
        return idInt > 0
    }
}
