//
//  TLVObject.swift
//  ios-device-lib
//

import Foundation

public class TLVObject: NSObject {

    public var tagName: String = ""
    public var tag: String = ""
    public var length: String?
    public var value: String?
    public var innerTlvs: [TLVObject]?

    public override init() {
        tagName = ""
        tag     = ""
        length  = nil
        value   = nil
        super.init()
    }

    public init(string tlvTag: String) {
        tag     = tlvTag
        tagName = Tag.tagName(tlvTag)
        super.init()
    }

    public static func generateHexString(from tlvObject: TLVObject?) -> String? {
        guard let tlvObject = tlvObject else { return nil }

        var hexString = ""

        hexString += tlvObject.tag

        if let lengthString = tlvObject.length,
           let lengthInt = Int(lengthString),
           let encodedLength = BerLength.getEncodedLengthHexString(lengthInt) {
            hexString += encodedLength
        } else {
            hexString += "00"
        }

        if let value = tlvObject.value {
            hexString += value
        }

        return hexString
    }

    public override func isEqual(_ other: Any?) -> Bool {
        guard let other = other as? TLVObject else { return false }
        if other === self { return true }
        return tag    == other.tag
            && length == other.length
            && value  == other.value
    }

    public override var hash: Int {
        var hasher = Hasher()
        hasher.combine(tag)
        hasher.combine(length)
        hasher.combine(value)
        return hasher.finalize()
    }

    public override var description: String {
        let name   = tagName.isEmpty ? tag : tagName
        let len    = length ?? "nil"
        let val    = value  ?? "nil"
        return "TLVObject(tag: \(tag) [\(name)], length: \(len), value: \(val))"
    }
}
