//
//  TokenizationTransaction.swift
//  ios-device-lib
//

import Foundation

public struct TokenizationTransaction: CardTransaction {

    public var posReferenceNumber: String?
    public var operatingUserId: String?
    public var invoiceNumber: String?
    public internal(set) var cardData: AnyCardData?
    public let clientTransactionId: String
    public var total: UInt?
    public var tip: UInt?
    public var cardholderAddress: Address?
    public var allowPartialAuth: Bool?
    public var cpcReq: Bool?
    public var isSurchargeEnabled: Bool?
    public var surchargeAmtInfo: String?
    public var surchargeRequested: SurchargeEligibility?
    public var surchargeFee: Decimal?
    
    private init(clientTransactionId: String?,
                 posReferenceNumber: String?,
                 invoiceNumber: String?,
                 operatingUserId: String?,
                 cardData: AnyCardData?,
                 allowPartialAuth: Bool?) {
        self.cardData = cardData
        self.posReferenceNumber = posReferenceNumber
        self.invoiceNumber = invoiceNumber
        self.operatingUserId = operatingUserId
        self.allowPartialAuth = allowPartialAuth
        if let clientTransactionIdValue = clientTransactionId, !clientTransactionIdValue.isEmpty {
            self.clientTransactionId = clientTransactionIdValue
        } else {
            self.clientTransactionId = UUID().uuidString
        }
    }

    public static func tokenize(clientTransactionId: String?,
                                posReferenceNumber: String?,
                                invoiceNumber: String?,
                                operatingUserId: String?,
                                allowPartialAuth: Bool?) -> TokenizationTransaction {
        return TokenizationTransaction(clientTransactionId: clientTransactionId,
                                       posReferenceNumber: clientTransactionId,
                                       invoiceNumber: invoiceNumber,
                                       operatingUserId: operatingUserId,
                                       cardData: nil,
                                       allowPartialAuth: allowPartialAuth)
    }

    public static func tokenize(clientTransactionId: String?,
                                posReferenceNumber: String?,
                                invoiceNumber: String?,
                                operatingUserId: String?,
                                cardData: ManualCardData,
                                allowPartialAuth: Bool?) -> TokenizationTransaction {
        var tokenize = TokenizationTransaction(clientTransactionId: clientTransactionId,
                                               posReferenceNumber: posReferenceNumber,
                                               invoiceNumber: invoiceNumber,
                                               operatingUserId: operatingUserId,
                                               cardData: AnyCardData(cardData: cardData),
                                               allowPartialAuth: allowPartialAuth)
        tokenize.cardholderAddress = cardData.cardHolderAddress

        return tokenize
    }
}
