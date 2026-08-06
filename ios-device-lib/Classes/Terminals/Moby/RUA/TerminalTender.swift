//
//  TerminalTender.swift
//  ios-device-lib
//

import Foundation

@objcMembers
public class TerminalTender: NSObject {

    public var paymentAppVersion = ""
    public var gatewayTransactionID: String?
    public var posReferenceNumber: String?
    public var disableEMV = false
    public var enableQuickChip = false
    public var amount: Int = 0 // Amounts in Pennies
    public var tip: Int = 0 // Amounts in Pennies
    public var salesTax: Int = 0 // Amounts in Pennies
    public var invoiceNumber: String?
    public var orderID: String?
    public var orderNotes: String?
    public var orderNumber: String?
    public var forcedAuthCode: String?
    public var signatureImage: UIImage?
    public var track1Data: String?
    public var track2Data: String?
    public var emulatedTrackData: String?
    public var fallbackSwipe = false
    public var emvContactlessToContactChip = false
    public var tlvData: String?
    public var encryptedTrackData: String?
    public var packEncryptedTrackData: String?
    public var ksn: String?
    public var pin: String?
    public var pinKsn: String?
    public var serviceCode: String?
    public var formatID: String?
    public var redactedPan: String?
    public var maskedPan: String?
    public var cardHolderName: String?
    public var cardNumber: String?
    public var cvv2: String?
    public var zip: String?
    public var expirationDate: String?
    public var deviceSerialNumber: String?
    public var kernelVersionNumber: String?
    public var transactionResult = TransactionResult.canceled
    public var countryCode = CountryCode.USA
    public var currencyCode = CurrencyCode.USD
    public var transactionType = TerminalTransactionType.auth
    public var tenderType = TenderType.credit
    public var cardDataSource = CardDataSource.none
    public var voidReason = ReversalReason.undefined
    public var emvFallbackCondition = GMSFallbackReason.none
    public var lastChipRead = LastChipRead.unknown
    public var cardholderAuthenticationMethod = CardholderAuthenticationMethod.notSet

    public var totalAmount: Int { // Amounts in Pennies
        return amount + salesTax + tip
    }
    public var cardType: CardType {
        var cardType = CardType.unknown
        if let cardNum = cardNumber {
            cardType = CreditCardHelper().getCardTypeFromRedactedPan(cardNumber: cardNum)
        } else if let cardNum = redactedPan {
            cardType = CreditCardHelper().getCardTypeFromRedactedPan(cardNumber: cardNum)
        } else if let cardNum = maskedPan {
            cardType = CreditCardHelper().getCardTypeFromRedactedPan(cardNumber: cardNum)
        }

        return cardType
    }
    public func isChipTransaction() -> Bool {
        return cardDataSource == CardDataSource.emv ||
            cardDataSource == CardDataSource.emvContactless ||
            cardDataSource == CardDataSource.quickChip
    }

    public static func cardholderAuthenticationMethodfromTlv(_ tlv: String?) -> CardholderAuthenticationMethod {

        guard let tlv = tlv else {
            return .notSet
        }

        var result = CardholderAuthenticationMethod.notAuthenticated
        var method = ""

        if tlv.count >= 2 {
            method = String(tlv.prefix(2))
        }

        switch method {
        case "", "3F", "7F":
            result = .notSet
        case "00", "1F", "5F":
            result = .notAuthenticated
        case "01":
            result = .offlinePin
        case "02", "42":
            result = .pin
        case "05", "45", "1E", "5E":
            result = .manualSignature
        default:
            result = .notAuthenticated
        }

        return result
    }
}
