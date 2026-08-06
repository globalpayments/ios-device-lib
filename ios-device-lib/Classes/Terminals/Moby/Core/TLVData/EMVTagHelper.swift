//
//  EMVTagHelper.swift
//  ios-device-lib
//

import Foundation

public class EMVTagHelper {

    public static var applicationIdentifier: Tag {
        return berTag(from: "4F")
    }

    public static var applicationLabel: Tag {
        return berTag(from: "50")
    }

    public static var applicationPrefName: Tag {
        return berTag(from: "9F12")
    }

    public static var bankIdentifier: Tag {
        return berTag(from: "5F54")
    }

    public static var cryptogram: Tag {
        return berTag(from: "9F27")
    }

    public static var emvChipIndicator: Tag {
        return berTag(from: "9F6E")
    }

    public static var merchantIdentifier: Tag {
        return berTag(from: "9F16")
    }

    public static var cardholderVerificationMethod: Tag {
        return berTag(from: "9F34")
    }

    public static var terminalIdentifier: Tag {
        return berTag(from: "9F1C")
    }

    public static var terminalVerificationResults: Tag {
        return berTag(from: "95")
    }

    public static var transactionStatusInformation: Tag {
        return berTag(from: "9B")
    }

    public static var cardHolderName: Tag {
        return berTag(from: "5F20")
    }

    private static func berTag(from value: String) -> Tag {
        return TLVUtility.tag(fromTLVString: value)
    }

    public static func cardholderAuthenticationMethod( fromTlv tlv: String?) -> CardholderAuthenticationMethod {

        let failCvmProcessing:                      Set<String> = ["00"]
        let plainTextOfflinePin:                    Set<String> = ["01"]
        let encipheredPin:                          Set<String> = ["02", "42"]
        let plainTextPinWithSignature:              Set<String> = ["05", "45"]
        let signature:                              Set<String> = ["1E", "5E"]
        let noCvm:                                  Set<String> = ["1F", "5F"]
        let cvmNotPerformed:                        Set<String> = ["3F", "7F"]

        guard let tlv = tlv,
              tlv.count >= 2 else {
            return .notSet
        }

        let method = String(tlv.prefix(2)).uppercased()

        if cvmNotPerformed.contains(method) {
            return .notSet
        } else if failCvmProcessing.contains(method) || noCvm.contains(method) {
            return .notAuthenticated
        } else if plainTextOfflinePin.contains(method) {
            return .offlinePin
        } else if encipheredPin.contains(method) {
            return .pin
        } else if plainTextPinWithSignature.contains(method) || signature.contains(method) {
            return .manualSignature
        } else {
            return .notAuthenticated
        }
    }
}
