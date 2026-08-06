//
//  CommonEnums.swift
//  ios-device-lib
//

import Foundation

public enum SurchargeEligibility: String, Codable, CodingKey {
    case Y, N, U
}

/// Indicates the components of the address needed for Address Verification System.
public enum AvsType: String {
    case zip, zipAddress, none
}

public enum CardType: String, Codable {
    case visa,
    amex,
    jcb,
    maestro,
    discover,
    unionPay,
    dinersClub,
    masterCard,
    tokenizedCard,
    unknown
}

public enum CountryCode: Int, Codable {
    case USA = 840
    case CAD = 124

    var stringDescription: String {
        get {
            switch self {
            case .USA: return "USA"
            case .CAD: return "CAD"
            }
        }
    }
}

public enum CurrencyCode: Int, Codable {
    case USD = 840
    case CAD = 124

    var stringDescription: String {
        get {
            switch self {
            case .USD: return "USD"
            case .CAD: return "CAD"
            }
        }
    }
}

/// Describes the type of cardholder verification that was performed and the result
public enum CvmResult: String, CaseIterable {
    case pinOnline = "01"
    case pinOfflineEncrypted = "02"
    case pinOfflinePlain = "03"
    case signatureRequired = "5E"
    case noCvmRequired = "1F"
    case notAvailable = "00"
}

public enum PinStatementType: String {
    case pinNotSupported,
    pinVerfied,
    pinBypassed,
    pinLocked
}

public enum LastChipRead: Int, Codable {
    case successful,
    failed,
    notAChipTransaction,
    unknown
}

public enum CardDataSource: Int {
    case swipe, nfc, emv, quickChip, emvContactless, manual, phone, fallbackSwipe, none
}

public enum TenderType: String {
    case credit, debit
}

enum CommercialCardDataField: Int {
    case purchaseOrderNumber,
    supplierRefNumber,
    customerRefID,
    shipToZip,
    chargeDescriptor
}

/// Indicates if the card is a purchasing or commercial card and if so, what type.
enum CommercialCard: Int {
    case business,
    visaCommerce,
    b2BSettlementEligible,
    corporate,
    purchase,
    nonCommercial
}

public enum AuthType {
    case manualCard
    case cardReader
    case unknown
}
