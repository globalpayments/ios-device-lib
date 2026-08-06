//
//  PorticoHelper.swift
//  ios-device-lib
//

import Foundation
import GlobalPaymentsApi

// MARK: CardTransaction Extension
extension CardTransaction {

    func buildGPCredit(_ cardData: AnyCardData) -> GPCredit {
        
        switch cardData.cardEntryMode {
        case .manual:
            return cardData.buildManualEntryCardData()

        case .contact, .contactless, .quickChip:
            return cardData.buildEmvCardTrackData()

        case .msr, .chipFallback:
            return cardData.buildMsrCardTrackData()
        case .token:
            return cardData.buildToken()
        }
    }
}

// MARK: AnyCardData Extension
extension AnyCardData {

    func buildManualEntryCardData() -> GPCredit {
        let card = cardData as! ManualCardData

        let manualEntryCardData = GPCreditCardData()

        manualEntryCardData.cardHolderName = card.cardholderName
        manualEntryCardData.number = card.cardNumber
        manualEntryCardData.cvn = card.cardPresent ? "" : card.cvv
        manualEntryCardData.cardPresent = card.cardPresent
        manualEntryCardData.readerPresent = card.readerPresent
        manualEntryCardData.expMonth = String(card.expirationDate.prefix(2))

        if card.expirationDate.count < 6 {
            manualEntryCardData.expYear = "20" + String(card.expirationDate.suffix(2))
        } else {
            manualEntryCardData.expYear = String(card.expirationDate.suffix(4))
        }

        return manualEntryCardData
    }

    func buildMsrCardTrackData() -> GPCredit {
        let card = cardData as! MSRCard

        let msrCardData = GPCreditTrackData()

        let msrEncryptionData = GPEncryptionData()
        msrEncryptionData.version = "05" // Version represents TDES encryption used by the device

        if let ksnString = card.ksn {
            msrEncryptionData.ksn = PorticoUtility.encodeHexString(toBase64From: ksnString)
        }

        // Track data
        if card.track1Length ?? 0 > 0 && card.track2Length ?? 0 > 0 {
            msrEncryptionData.trackNumber = "2"

            if let track1 = card.encryptedTrack1,
                let track2 = card.encryptedTrack2 {

                msrCardData.value = PorticoUtility.encodeHexString(toBase64From: track1 + track2)
            }
        } else if card.track1Length ?? 0 > 0 {
            msrEncryptionData.trackNumber = "1"

            if let track1 = card.encryptedTrack1 {
                msrCardData.value = PorticoUtility.encodeHexString(toBase64From: track1)
            }
        } else if card.track2Length ?? 0 > 0 {
            msrEncryptionData.trackNumber = "2"

            if let track2 = card.encryptedTrack2 {
                msrCardData.value = PorticoUtility.encodeHexString(toBase64From: track2)
            }
        }

        msrCardData.encryptionData = msrEncryptionData

        return msrCardData
    }

    func buildEmvCardTrackData() -> GPCredit {
        let card = cardData as! EMVCard

        let emvEncryptionData = GPEncryptionData()
        emvEncryptionData.version = "05" // Version represents TDES encryption used by the device
        emvEncryptionData.trackNumber = "2"
        
        if case .ingenico_moby5500 = card.terminalType {
//            emvEncryptionData.ksn = PorticoUtility.encodeHexStringToBase64(from: ksn)
            emvEncryptionData.ksn = PorticoUtility.encodeHexString(toBase64From:
                                                                            Utilities.fetchMobyKsnEquivalentData(fromEmvTags: TLVDecoder.decode(withTLVString: card.tlvData)) ?? "")
            
        } else {
           
            emvEncryptionData.ksn = PorticoUtility.encodeHexString(toBase64From:
                                                                            Utilities.fetchKsnEquivalentData(fromEmvTags: TLVDecoder.decode(withTLVString: card.tlvData)) ?? "")
        }
        
        let emvCardData = GPCreditTrackData()
        emvCardData.encryptionData = emvEncryptionData
        
        if case .ingenico_moby5500 = card.terminalType {
           
//            emvCardData.value = PorticoUtility.encodeHexStringToBase64(from: encryptedTrack1)
            emvCardData.value = PorticoUtility.encodeHexString(toBase64From:
                                                                        Utilities.fetchMobyTrack2EquivalentData(fromEmvTags: TLVDecoder.decode(withTLVString: card.tlvData)) ?? "")
            
        } else {
            
            emvCardData.value = PorticoUtility.encodeHexString(toBase64From:
                                                                        Utilities.fetchTrack2EquivalentData(fromEmvTags: TLVDecoder.decode(withTLVString: card.tlvData)) ?? "")
        }
        emvCardData.encryptionData = emvEncryptionData
        emvCardData.entryMethod = card.cardEntryMode == .contactless ? .proximity : .swipe

        return emvCardData
    }

    func buildToken() -> GPCredit {
        let card = cardData as! TokenizedCardData

        let tokenData = GPCreditCardData()
        tokenData.token = card.token
        // FIXME: Test if we are receiving any other data apart from Token

        return tokenData
    }
}

// MARK: GPAddress Extension
extension GPAddress {

    /// Initialization with Customer Address
    /// - Parameter address: Customer Addess object
    convenience init(_ address: Address) {
        self.init()

        streetAddress1 = address.addressLine1
        streetAddress2 = address.addressLine2
        city = address.city
        postalCode = address.postalCode
        addressType = .billingAddress
    }
}

// MARK: GPAuthorizationBuilder Extension
extension GPAuthorizationBuilder {

    func updateBuilder(_ transaction: CardTransaction) {
        amount = transaction.total?.amountInDollarString
        gratuity = transaction.tip != nil ? transaction.tip!.amountInDollarString : "0"
        invoiceNumber = transaction.invoiceNumber
        customerId = transaction.operatingUserId // FIXME: Add Customer struct if required to pass customer email address
        transactionDescription = "Credit Transaction with Amount: " + amount
        allowPartialAuth = transaction.allowPartialAuth ?? false
        cpcReq = transaction.cpcReq ?? false

        switch transaction.cardData?.cardEntryMode {
        case .manual:
            let card = transaction.cardData?.cardData as! ManualCardData

            if let address = card.cardHolderAddress {
                billingAddress = GPAddress(address)
            }
            break

        case .chipFallback:
            chipCondition = .chipFailedPreviousSuccess
            break

        case .contact, .contactless, .quickChip:
            // Remove portico blacklisted tags before mapping to builder
            let card = transaction.cardData?.cardData as! EMVCard
            let tlvData = TLVUtility.stripTags(emvTagDescriptors: Utilities.porticoBlackListedEmvTags(), fromEmvTags: TLVDecoder.decode(withTLVString: card.tlvData))
            // Map TLV Data
            tagData = TLVUtility.fetchIccDataString(fromEmvTagsArray: tlvData)
            break

        default:
            break
        }
    }
    
    func updateBuilderForVerify(_ transaction: CardTransaction) {
        if let address = transaction.cardholderAddress {
            billingAddress = GPAddress(address)
        }
        switch transaction.cardData?.cardEntryMode {
        case .manual:
            let card = transaction.cardData?.cardData as! ManualCardData

            if let address = card.cardHolderAddress {
                billingAddress = GPAddress(address)
            }
            break

        case .chipFallback:
            chipCondition = .chipFailedPreviousSuccess
            break

        case .contact, .contactless, .quickChip:
            // Remove portico blacklisted tags before mapping to builder
            let card = transaction.cardData?.cardData as! EMVCard
            let tlvData = TLVUtility.stripTags(emvTagDescriptors: Utilities.porticoBlackListedEmvTags(), fromEmvTags: TLVDecoder.decode(withTLVString: card.tlvData))
            // Map TLV Data
            tagData = TLVUtility.fetchIccDataString(fromEmvTagsArray: tlvData)
            break

        default:
            break
        }
    }
}

extension TaxCategory {

    var gpTaxType: GPTaxType {
        switch self {
        case .sale:
            return .salesTax
        case .taxExempt:
            return.taxExempt
        default:
            return .notUsed
        }
    }
}
