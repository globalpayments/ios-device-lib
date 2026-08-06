//
//  TLVDecoder.swift
//  ios-device-lib
//

import Foundation
import os.log

public class TLVDecoder {

    private init() {}

    public static func decode(withTLVString tlv: String?) -> [TLVObject]? {
        guard let tlv = tlv else {
            os_log("TLVDecoder: TLV is nil")
            return nil
        }
        guard tlv.count % 2 == 0 else {
            os_log("TLVDecoder: Invalid TLV — odd number of characters")
            return nil
        }

        var bytes = [Int]()
        bytes.reserveCapacity(tlv.count / 2)

        var index = tlv.startIndex
        while index < tlv.endIndex {
            let nextIndex = tlv.index(index, offsetBy: 2)
            let byteStr = String(tlv[index..<nextIndex])
            bytes.append(hexToInt(byteStr))
            index = nextIndex
        }

        return decodeTLV(bytes)
    }

    public static func decodeTLV(_ bytes: [Int]?) -> [TLVObject]? {
        guard let bytes = bytes, !bytes.isEmpty else { return nil }

        var tlvObjects   = [TLVObject]()
        var tagBytes     = [Int]()
        var cursor       = 0
        let extent       = bytes.count
        var resetPosition = 0

        while cursor < extent {

            if resetPosition > 0 {
                cursor = resetPosition
            }

            var actualTag    = ""
            var actualLength = 0
            var actualValue  = ""
            var tagIsConstructed = true

            guard cursor < bytes.count else { break }

            tagBytes.append(bytes[cursor])
            let firstTag = tagBytes[0]

            guard Tag.isValid(firstTag) else {
                tagBytes.removeAll()
                cursor += 1
                continue
            }

            tagIsConstructed = Tag.isConstructed(firstTag)

            if Tag.isMultiByte(firstTag) {
                cursor += 1
                guard cursor < bytes.count else { break }
                tagBytes.append(bytes[cursor])

                if !Tag.isLast(bytes[cursor]) {
                    cursor += 1
                    guard cursor < bytes.count else { break }
                    tagBytes.append(bytes[cursor])
                }
            }

            actualTag = tagBytes
                .map { String(format: "%02X", $0) }
                .joined()

            let tlvObject = TLVObject(string: actualTag)
            tagBytes.removeAll()

            cursor += 1
            resetPosition = cursor

            guard cursor < bytes.count else { break }

            let lengthByte = bytes[cursor]

            guard BerLength.isValid(lengthByte) else {
                tlvObject.length = "0"
                tlvObjects.append(tlvObject)
                cursor += 1
                continue
            }

            resetPosition = 0

            let lengthExtent = BerLength.getLength(lengthByte)
            actualLength     = lengthByte

            if BerLength.isMultiByte(lengthByte) {
                var lengthCursor = 0
                var lengthParts  = [Int]()

                while lengthCursor < lengthExtent {
                    cursor += 1
                    guard cursor < bytes.count else { break }
                    let shifted = bytes[cursor] << ((lengthExtent - lengthCursor - 1) * 8)
                    lengthParts.append(shifted)
                    lengthCursor += 1
                }

                guard cursor < bytes.count else { break }

                actualLength = lengthParts.reduce(0) { $0 | $1 }
            }

            tlvObject.length = "\(actualLength)"

            if actualLength > (bytes.count - 1 - cursor) {
                tlvObjects.append(tlvObject)
                cursor += 1
                continue
            } else {
                resetPosition = 0
            }

            cursor += 1
            guard cursor < bytes.count else { break }

            if actualLength > (bytes.count - 1 - cursor) {
                let valueBytes = Array(bytes[cursor...])
                actualValue    = valueBytes
                    .map { String(format: "%02X", $0) }
                    .joined()
                tlvObject.value = actualValue
                tlvObjects.append(tlvObject)
                break
            }

            let valueBytes = Array(bytes[cursor ..< cursor + actualLength])

            if tagIsConstructed {
                tlvObject.innerTlvs = decodeTLV(valueBytes)
            }

            actualValue = valueBytes
                .map { String(format: "%02X", $0) }
                .joined()

            cursor += actualLength

            tlvObject.value = actualValue
            tlvObjects.append(tlvObject)
        }

        return tlvObjects.isEmpty ? nil : tlvObjects
    }

    public static func hexToInt(_ hex: String?) -> Int {
        guard let hex = hex else { return 0 }
        return Int(hex, radix: 16) ?? 0
    }
}
