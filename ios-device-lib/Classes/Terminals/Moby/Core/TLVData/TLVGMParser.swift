//
//  TLVGMParser.swift
//  ios-device-lib
//

import Foundation
import os.log

public class TLVGMParser {

    private init() {}

    public static func splitTLVData(_ tlvString: String?) -> [String]? {
        guard let tlvString = tlvString,
              let data = TLVUtility.data(withHexString: tlvString) else {
            return nil
        }

        let bytes        = [UInt8](data)
        var tags         = [String]()
        var tagStart     = 0
        var tagEnd       = 0
        var lengthStart  = 0
        var lengthEnd    = 0
        var contentStart = 0
        var contentEnd   = 0
        var currentTag   = Tag()
        var berLen       = BerLength()

        for i in 0..<bytes.count {
            let c = bytes[i]

            if tagStart == i {
                currentTag          = Tag()
                currentTag.tagClass = Tag.tagClass(fromChar: c)
                currentTag.tagType  = Tag.tagIsPrimitive(c) ? .primitive : .constructed
                let identifier      = Tag.tagIdentifier(c, firstByte: true)

                if identifier > 30 {
                    tagEnd = tagStart + 1
                } else {
                    currentTag.value = data.subdata(in: tagStart..<tagStart + 1)
                    lengthStart      = i + 1
                }

            } else if tagEnd == i {
                if Tag.tagIdentifierIsLastByte(c) {
                    currentTag.value = data.subdata(in: tagStart..<1 + tagEnd)
                    lengthStart      = i + 1
                } else {
                    tagEnd += 1
                }

            } else if lengthStart == i {
                lengthEnd = lengthStart
                let lengthType = BerLength.getTagLengthType(c)

                switch lengthType {
                case .indefinite:
                    os_log("TLVGMParser: BerLengthTypeIndefinite — unimplemented")

                case .definiteLong:
                    os_log("TLVGMParser: BerLengthTypeDefiniteLong — unimplemented")
                    lengthEnd = lengthStart + 1

                case .definiteShort:
                    berLen       = BerLength()
                    berLen.value = data.subdata(in: lengthStart..<1 + lengthEnd)
                    contentStart = i + 1
                    contentEnd   = i + Int(c)
                    tagStart     = contentEnd + 1

                    let berValue      = BerValue()
                    let valueEnd      = min(contentStart + (contentEnd - contentStart + 1), data.count)
                    berValue.value    = data.subdata(in: contentStart..<valueEnd)

                    // Build: tag hex + length hex + value hex
                    var tlv = ""
                    if let tagData   = currentTag.value {
                        tlv += tagData.map { String(format: "%02X", $0) }.joined()
                    }
                    if let lenData   = berLen.value {
                        tlv += lenData.map { String(format: "%02X", $0) }.joined()
                    }
                    if let valData   = berValue.value {
                        tlv += valData.map { String(format: "%02X", $0) }.joined()
                    }
                    tags.append(tlv)

                @unknown default:
                    break
                }

            } else if lengthEnd == i {
                os_log("TLVGMParser: BerLengthTypeDefiniteLong continuation — unimplemented")
            }
        }

        return tags.isEmpty ? nil : tags
    }

    public static func tlvObjects(fromTLVData tlvString: String?) -> [TLVObject]? {
        guard let tlvStrings = splitTLVData(tlvString) else { return nil }
        return tlvStrings.map { TLVObject(string: $0) }
    }

    public static func isIssuerScriptTemplate1(_ tlv: String) -> Bool {
        guard let value = TLVUtility.tag(fromTLVString: tlv).value,
              value.count == 1 else { return false }
        return value[0] == 0x71
    }

    public static func isIssuerScriptTemplate2(_ tlv: String) -> Bool {
        guard let value = TLVUtility.tag(fromTLVString: tlv).value,
              value.count == 1 else { return false }
        return value[0] == 0x72
    }

    public static func cleanTagsForGateway(_ tender: TerminalTender) -> [String]? {
        guard var emvTags = splitTLVData(tender.tlvData) else { return nil }

        var tagsToRemove = [String]()

        if tender.cardDataSource == .nfc {
            let allowedPrefixes = ["4F", "9F06", "9F12", "50", "9F6E"]
            tagsToRemove = emvTags.filter { tlv in
                !allowedPrefixes.contains(where: { tlv.hasPrefix($0) })
            }
        } else {
            let blockedPrefixes = ["9F0F", "9F0E", "9F0D", "9F1F", "9F20"]
            tagsToRemove = emvTags.filter { tlv in
                blockedPrefixes.contains(where: { tlv.hasPrefix($0) })
            }
        }

        emvTags.removeAll { tagsToRemove.contains($0) }

        let hasDF78 = emvTags.contains { $0.hasPrefix("DF78") }
        if !hasDF78 {
            if let serial    = tender.deviceSerialNumber,
               let serialData = serial.data(using: .ascii) {
                let hexSerial = serialData
                    .map { String(format: "%02X", $0) }
                    .joined()
                let tag = String(format: "DF78%02X%@",
                                 hexSerial.count / 2,
                                 hexSerial)
                emvTags.append(tag)
            }
        }

        let hasDF79 = emvTags.contains { $0.hasPrefix("DF79") }
        if !hasDF79 {
            if let kernel = tender.kernelVersionNumber {
                let tag = String(format: "DF79%02X%@",
                                 kernel.count / 2,
                                 kernel)
                emvTags.append(tag)
            }
        }

        return emvTags
    }
}
