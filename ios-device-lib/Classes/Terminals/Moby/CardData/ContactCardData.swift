//
//  ContactCardData.swift
//  ios-device-lib
//

import Foundation

struct ContactCardData: EMVCard {

    var cardEntryMode: EntryMode

    // MARK: EMVCard Properties
    var cardholderName: String?
    var encryptedTrack1: String?
    var encryptedTrack2: String?
    var tlvData: String
    var expirationDate: String?
    var formatID: Int?
    var ksn: String?
    var maskedPAN: String?
    var serialNumber: String?
    var serviceCode: Int?
    var track1Length: Int?
    var track2Length: Int?
    var aid: String?
    var applicationLabel: String?
    var cvm: String?
    var tsi: String?
    var tvr: String?
    var terminalType: TerminalType = .none

    private init(cardholderName: String?,
                 encryptedTrack1: String?,
                 encryptedTrack2: String?,
                 expirationDate: String?,
                 formatID: Int?,
                 ksn: String?,
                 maskedPAN: String?,
                 serialNumber: String?,
                 serviceCode: Int?,
                 tlvData: String,
                 terminalType: TerminalType) {
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
        self.tlvData = tlvData
        self.cardEntryMode = .contact
        self.terminalType = terminalType

        let tags = TLVDecoder.decode(withTLVString: tlvData)

        if let obj = TLVUtility.findTLVObject(.applicationIdentifier, fromArray: tags) {
            aid = obj.value
        }
        if let obj = TLVUtility.findTLVObject(.appLabel, fromArray: tags) {
            applicationLabel = obj.value
        }
        if let obj = TLVUtility.findTLVObject(.transactionStatusInformation, fromArray: tags) {
            tsi = obj.value
        }
        if let obj = TLVUtility.findTLVObject(.cvmResult, fromArray: tags) {
            cvm = obj.value
        }
        if let obj = TLVUtility.findTLVObject(.terminalVerificationResults, fromArray: tags) {
            tvr = obj.value
        }
        
        if let obj = TLVUtility.findTLVObject(.cardholderName, fromArray: tags) {
            
            self.cardholderName = obj.value
        }
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
                         tlvData: String,
                         terminalType: TerminalType) -> ContactCardData {
        return self.init(cardholderName: cardholderName,
                         encryptedTrack1: encryptedTrack1,
                         encryptedTrack2: encryptedTrack2,
                         expirationDate: expirationDate,
                         formatID: formatID,
                         ksn: ksn,
                         maskedPAN: maskedPAN,
                         serialNumber: serialNumber,
                         serviceCode: serviceCode,
                         tlvData: tlvData,
                         terminalType: terminalType)
    }
}
