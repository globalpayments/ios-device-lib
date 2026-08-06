//
//  TLVUtility.swift
//  ios-device-lib
//

import Foundation
import os.log

public class TLVUtility: NSObject {

    public static let shared = TLVUtility()
    private override init() { super.init() }

    public static func asciiToHex(_ string: String?) -> String? {
        guard let string = string, !string.isEmpty else { return nil }

        guard let data = string.data(using: .utf8) else { return nil }

        return data
            .map { String(format: "%02X", $0) }
            .joined()
    }

    public static func hexToAscii(_ hex: String?) -> String? {
        guard let hex = hex else { return "" }
        guard hex.count % 2 == 0 else { return "" }

        var result = ""
        var index = hex.startIndex

        while index < hex.endIndex {
            let nextIndex = hex.index(index, offsetBy: 2)
            let byteStr   = String(hex[index..<nextIndex])
            if let value  = UInt32(byteStr, radix: 16),
               let scalar = Unicode.Scalar(value) {
                result.append(Character(scalar))
            }
            index = nextIndex
        }

        return result
    }

    public static func data(withHexString hex: String) -> Data? {
        guard hex.count % 2 == 0 else {
            assertionFailure("Hex strings must have an even number of digits: \(hex)")
            return nil
        }

        var data  = Data(capacity: hex.count / 2)
        var index = hex.startIndex

        while index < hex.endIndex {
            let nextIndex = hex.index(index, offsetBy: 2)
            let byteStr   = String(hex[index..<nextIndex])
            guard let byte = UInt8(byteStr, radix: 16) else {
                assertionFailure("Invalid hex character in: \(hex) around index \(hex.distance(from: hex.startIndex, to: index))")
                return nil
            }
            data.append(byte)
            index = nextIndex
        }

        return data
    }

    public static func dataToHexString(_ data: Data?) -> String? {
        guard let data = data, !data.isEmpty else { return nil }
        return data.map { String(format: "%02X", $0) }.joined()
    }

    public static func tag(fromTLVString tlvString: String?) -> Tag {
        let fallback = Tag()

        guard let tlvString = tlvString,
              let data = self.data(withHexString: tlvString) else {
            return fallback
        }

        let bytes    = [UInt8](data)
        var tagStart = 0
        var tagEnd   = 0
        var tag      = Tag()

        for i in 0..<bytes.count {
            let c = bytes[i]

            if tagStart == i {
                tag = Tag()
                tag.tagClass = Tag.tagClass(fromChar: c)
                tag.tagType  = Tag.tagIsPrimitive(c) ? .primitive : .constructed

                let identifier = Tag.tagIdentifier(c, firstByte: true)

                if identifier > 30 {
                    tagEnd = tagStart + 1
                } else {
                    tag.value = data.subdata(in: tagStart..<tagStart + 1)
                }
            } else if tagEnd == i {
                if Tag.tagIdentifierIsLastByte(c) {
                    tag.value = data.subdata(in: tagStart..<1 + tagEnd)
                    return tag
                } else {
                    tagEnd += 1
                }
            }
        }

        return tag
    }

    public static func tagValue(fromTLV tlv: String) -> String? {
        guard let data = self.data(withHexString: tlv) else { return "" }

        let bytes        = [UInt8](data)
        var parsedValue  = ""
        var tagStart     = 0
        var tagEnd       = 0
        var lengthStart  = 0
        var lengthEnd    = 0
        var contentStart = 0
        var contentEnd   = 0
        var tag          = Tag()

        for i in 0..<bytes.count {
            let c = bytes[i]

            if tagStart == i {
                tag = Tag()
                tag.tagClass = Tag.tagClass(fromChar: c)
                tag.tagType  = Tag.tagIsPrimitive(c) ? .primitive : .constructed
                let identifier = Tag.tagIdentifier(c, firstByte: true)

                if identifier > 30 {
                    tagEnd = tagStart + 1
                } else {
                    tag.value = data.subdata(in: tagStart..<tagStart + 1)
                    lengthStart = i + 1
                }

            } else if tagEnd == i {
                if Tag.tagIdentifierIsLastByte(c) {
                    tag.value   = data.subdata(in: tagStart..<1 + tagEnd)
                    lengthStart = i + 1
                } else {
                    tagEnd += 1
                }

            } else if lengthStart == i {
                lengthEnd = lengthStart
                let lengthType = BerLength.getTagLengthType(c)

                switch lengthType {
                case .indefinite:
                    os_log("TLVUtility: BerLengthTypeIndefinite — unimplemented")

                case .definiteLong:
                    os_log("TLVUtility: BerLengthTypeDefiniteLong — unimplemented")
                    lengthEnd = lengthStart + 1

                case .definiteShort:
                    let berLen = BerLength()
                    berLen.value = data.subdata(in: lengthStart..<1 + lengthEnd)
                    contentStart = i + 1
                    contentEnd   = i + Int(c)
                    tagStart     = contentEnd + 1

                    let valueRange = contentStart..<contentStart + (contentEnd - contentStart + 1)
                    if valueRange.upperBound <= data.count {
                        let valueData = data.subdata(in: valueRange)
                        parsedValue   = valueData
                            .map { String(format: "%02X", $0) }
                            .joined()
                    }

                @unknown default:
                    break
                }

            } else if lengthEnd == i {
                os_log("TLVUtility: BerLengthTypeDefiniteLong continuation — unimplemented")
            }
        }

        return parsedValue
    }

    public static func findTLVObject(_ tag: EMVTagDescriptor, fromArray tlvArray: [TLVObject]?
    ) -> TLVObject? {
        guard let tlvArray = tlvArray, !tlvArray.isEmpty else { return nil }

        let targetTag = Utilities.hexString(fromEMVTagEnum: tag)
        var result: TLVObject?

        for obj in tlvArray {
            if obj.tag == targetTag {
                result = obj
            } else if let innerTlvs = obj.innerTlvs, !innerTlvs.isEmpty {
                for inner in innerTlvs where inner.tag == targetTag {
                    result = inner
                    break
                }
            }
            if result != nil { break }
        }

        return result
    }

    public static func createTLV(fromTag tag: String, andValue value: String) -> String? {
        let halfLength = value.count / 2

        if halfLength <= 127 {
            return String(format: "%@%02X%@", tag, halfLength, value)
        } else if halfLength <= 255 {
            return String(format: "%@81%02X%@", tag, halfLength, value)
        } else {
            return String(format: "%@82%04X%@", tag, halfLength, value)
        }
    }

    public static func isIssuerScriptTemplate1(_ tlv: String) -> Bool {
        guard let tagObj = tag(fromTLVString: tlv) as Tag?,
              let value  = tagObj.value,
              value.count == 1 else { return false }
        return value[0] == 0x71
    }

    public static func isIssuerScriptTemplate2(_ tlv: String) -> Bool {
        guard let tagObj = tag(fromTLVString: tlv) as Tag?,
              let value  = tagObj.value,
              value.count == 1 else { return false }
        return value[0] == 0x72
    }

    public static func fetchIccDataString(
        fromEmvTagsDictionary emvTags: [String: String]?
    ) -> String? {
        guard let emvTags = emvTags, !emvTags.isEmpty else { return nil }

        return emvTags.compactMap { tag, value in
            createTLV(fromTag: tag, andValue: value)
        }.joined()
    }

    public static func fetchIccDataString(
        fromEmvTagsArray emvTags: [TLVObject]?
    ) -> String? {
        guard let emvTags = emvTags, !emvTags.isEmpty else { return nil }

        return emvTags
            .compactMap { TLVObject.generateHexString(from: $0) }
            .joined()
    }

    public static func stripTags(
        emvTagDescriptors tagDescriptors: [String]?,
        fromEmvTags array: [TLVObject]?
    ) -> [TLVObject]? {
        guard let array = array, !array.isEmpty else { return array }
        guard let tagDescriptors = tagDescriptors,
              !tagDescriptors.isEmpty else { return array }

        return array.filter { !tagDescriptors.contains($0.tag) }
    }
}
