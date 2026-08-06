//
//  Utilities.swift
//  ios-device-lib
//

import Foundation

public class Utilities {

    private init() {}

    public static func hexString(fromEMVTagEnum hexNumber: EMVTagDescriptor) -> String {
        return String(format: "%lX", hexNumber.rawValue)
    }

    public static func porticoBlackListedEmvTags() -> [String]? {
        var blackListArray = [String]()

        blackListArray.append(hexString(fromEMVTagEnum: .bbposArqcDecryptionKsn))
        blackListArray.append(hexString(fromEMVTagEnum: .bbposOnlinePinKsn))
        blackListArray.append(hexString(fromEMVTagEnum: .bbposEncryptedOnlineMessage))
        blackListArray.append(hexString(fromEMVTagEnum: .bbposAacTcDecryptionKsn))
        blackListArray.append(hexString(fromEMVTagEnum: .bbposMaskedPan))
        blackListArray.append(hexString(fromEMVTagEnum: .bbposEncryptedBatchMessage))
        blackListArray.append(hexString(fromEMVTagEnum: .bbposEncryptedReversalMessage))
        blackListArray.append(hexString(fromEMVTagEnum: .bbposTrack2EquivalentDataKsn))
        blackListArray.append(hexString(fromEMVTagEnum: .bbposTrack2EquivalentData))

        blackListArray.append(hexString(fromEMVTagEnum: .bbposSerialNumber))
        blackListArray.append(hexString(fromEMVTagEnum: .bbposBid))
        blackListArray.append(hexString(fromEMVTagEnum: .bbposQuickChipIndicator))

        blackListArray.append(hexString(fromEMVTagEnum: .bbposProprietaryTag1))
        blackListArray.append(hexString(fromEMVTagEnum: .bbposProprietaryTag2))
        blackListArray.append(hexString(fromEMVTagEnum: .bbposProprietaryTag3))
        blackListArray.append(hexString(fromEMVTagEnum: .bbposWisecubeUnknownTag1))
        blackListArray.append(hexString(fromEMVTagEnum: .bbposWisecubeUnknownTag2))

        blackListArray.append(hexString(fromEMVTagEnum: .moby5500Track2EquivalentDataKsn))
        blackListArray.append(hexString(fromEMVTagEnum: .moby5500Track2EquivalentData))

        return blackListArray.isEmpty ? nil : blackListArray
    }

    public static func fetchKsnEquivalentData(fromEmvTags emvTags: [TLVObject]?) -> String? {
        guard let emvTags = emvTags else { return nil }
        let targetTag = hexString(fromEMVTagEnum: .bbposTrack2EquivalentDataKsn)
        return emvTags.first { $0.tag == targetTag }?.value
    }

    public static func fetchTrack2EquivalentData(fromEmvTags emvTags: [TLVObject]?) -> String? {
        guard let emvTags = emvTags else { return nil }
        let targetTag = hexString(fromEMVTagEnum: .bbposTrack2EquivalentData)
        return emvTags.first { $0.tag == targetTag }?.value
    }

    public static func convertString(toByteArray string: String?) -> [NSNumber]? {
        guard let string = string,
              !string.isEmpty,
              string.count % 2 == 0 else { return nil }

        var byteArray = [NSNumber]()
        byteArray.reserveCapacity(string.count / 2)

        var index = string.startIndex
        while index < string.endIndex {
            let nextIndex = string.index(index, offsetBy: 2)
            let byteStr = String(string[index ..< nextIndex])
            guard let byte = UInt64(byteStr, radix: 16) else { return nil }
            byteArray.append(NSNumber(value: byte))
            index = nextIndex
        }

        return byteArray
    }

    public static func fetchMobyKsnEquivalentData(fromEmvTags emvTags: [TLVObject]?) -> String? {
        guard let emvTags = emvTags else { return nil }
        let targetTag = hexString(fromEMVTagEnum: .moby5500Track2EquivalentDataKsn)
        return emvTags.first { $0.tag == targetTag }?.value
    }

    public static func fetchMobyTrack2EquivalentData(fromEmvTags emvTags: [TLVObject]?) -> String? {
        guard let emvTags = emvTags else { return nil }
        let targetTag = hexString(fromEMVTagEnum: .moby5500Track2EquivalentData)
        return emvTags.first { $0.tag == targetTag }?.value
    }
}
