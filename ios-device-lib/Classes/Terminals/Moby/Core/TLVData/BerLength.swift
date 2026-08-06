//
//  BerLength.swift
//  ios-device-lib
//

import Foundation

public class BerLength: NSObject {

    public var value: Data?

    public var type: BerLengthType = .definiteShort

    public override init() {
        super.init()
    }

    public init(value: Data?, type: BerLengthType) {
        self.value = value
        self.type  = type
        super.init()
    }

    public static func getTagLengthType(_ byte: UInt8) -> BerLengthType {
        if byte == 0x80 {
            return .indefinite
        } else if (byte & 0x80) != 0 {
            return .definiteLong
        } else {
            return .definiteShort
        }
    }

    public static func isTagLengthLastByte(_ byte: UInt8) -> Bool {
        return (byte & 0x80) == 0
    }

    public static func getNumberOfBytesToEncodedLength(_ length: Int) -> Int {
        if length < 0x80 {
            return 1
        } else if length <= 0xFF {
            return 2
        } else {
            return 3
        }
    }

    public static func getEncodedLengthHexString(_ length: Int) -> String? {
        guard let data = getEncodedLength(length) else { return nil }
        return data.map { String(format: "%02X", $0) }.joined()
    }
    
    public static func getEncodedLength(_ length: Int) -> Data? {
        let byteCount = getNumberOfBytesToEncodedLength(length)
        var lengthBytes = Data(count: byteCount)
        encodeLength(length, into: &lengthBytes, atOffset: 0)
        return lengthBytes
    }

    public static func encodeLength(
        _ length: Int,
        into data: inout Data,
        atOffset offset: Int
    ) {
        var idx = offset

        if length <= 127 {
            data[idx] = UInt8(length)

        } else if length <= 255 {
            data[idx] = 0x81; idx += 1
            data[idx] = UInt8(length)

        } else {
            data[idx] = 0x82;                      idx += 1
            data[idx] = UInt8((length >> 8) & 0xFF); idx += 1
            data[idx] = UInt8(length & 0xFF)
        }
    }

    public static func isValid(_ byte: Int) -> Bool {
        return byte != 0x80 && byte >= 0x00 && byte <= 0x84
    }

    public static func getLength(_ byte: Int) -> Int {
        return byte & 0x7F
    }

    public static func isMultiByte(_ byte: Int) -> Bool {
        return (byte >> 7) == 0x01
    }
}
