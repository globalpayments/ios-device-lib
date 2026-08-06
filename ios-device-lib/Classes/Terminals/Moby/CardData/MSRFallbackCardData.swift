//
//  MSRFallbackCardData.swift
//  ios-device-lib
//

import Foundation

struct MSRFallbackCardData: MSRCard {

    var cardEntryMode: EntryMode

    // MARK: MSRCard Properties
    var cardholderName: String?
    var maskedPAN: String?
    var encryptedTrack1: String?
    var encryptedTrack2: String?
    var expirationDate: String?
    var formatID: Int?
    var ksn: String?
    var serialNumber: String?
    var serviceCode: Int?
    var track1Length: Int?
    var track2Length: Int?
    let fallbackReason: GMSFallbackReason
    var terminalType: TerminalType = .none

    // MARK: Init
    private init(cardholderName: String?,
                 encryptedTrack1: String?,
                 encryptedTrack2: String?,
                 expirationDate: String?,
                 formatID: Int?,
                 ksn: String?,
                 maskedPAN: String?,
                 serialNumber: String?,
                 serviceCode: Int?,
                 fallbackReason: GMSFallbackReason,
                 terminalType: TerminalType) {
        self.fallbackReason = fallbackReason
        self.cardholderName = cardholderName
        self.expirationDate = expirationDate
        self.formatID = formatID
        self.ksn = ksn
        self.maskedPAN = maskedPAN
        self.serialNumber = serialNumber
        self.serviceCode = serviceCode
        self.encryptedTrack1 = encryptedTrack1
        self.encryptedTrack2 = encryptedTrack2
        self.track1Length = encryptedTrack1?.count
        self.track2Length = encryptedTrack2?.count
        self.cardEntryMode = .chipFallback
        self.terminalType = terminalType
    }

    static func cardData(cardholderName: String?,
                         encryptedTrack1: String?,
                         encryptedTrack2: String?,
                         expirationDate: String?,
                         formatID: Int?,
                         ksn: String?,
                         maskedPAN: String?,
                         serialNumber: String?,
                         serviceCode: Int?,
                         fallbackReason: GMSFallbackReason,
                         terminalType: TerminalType) -> MSRFallbackCardData {
        return self.init(cardholderName: cardholderName,
                         encryptedTrack1: encryptedTrack1,
                         encryptedTrack2: encryptedTrack2,
                         expirationDate: expirationDate,
                         formatID: formatID,
                         ksn: ksn,
                         maskedPAN: maskedPAN,
                         serialNumber: serialNumber,
                         serviceCode: serviceCode,
                         fallbackReason: fallbackReason,
                         terminalType: terminalType)
    }
}
