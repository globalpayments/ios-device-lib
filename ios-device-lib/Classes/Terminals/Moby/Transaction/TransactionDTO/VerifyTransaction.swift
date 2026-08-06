//
//  VerifyTransaction.swift
//  ios-device-lib
//

import Foundation

public struct VerifyTransaction: CardTransaction {
    
    public var total: UInt?
    public var tip: UInt?
    public let clientTransactionId: String
    public var posReferenceNumber: String?
    public var operatingUserId: String?
    public var invoiceNumber: String?
    public internal(set) var cardData: AnyCardData?
    public var requestMultiUseToken = false
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
                 requestMultiUseToken: Bool,
                 allowPartialAuth: Bool?) {
        self.total = 0
        self.tip = 0
        self.cardData = cardData
        self.posReferenceNumber = posReferenceNumber
        self.invoiceNumber = invoiceNumber
        self.operatingUserId = operatingUserId
        if let clientTransactionIdValue = clientTransactionId, !clientTransactionIdValue.isEmpty {
            self.clientTransactionId = clientTransactionIdValue
        } else {
            self.clientTransactionId = UUID().uuidString
        }
        self.requestMultiUseToken = requestMultiUseToken
        self.allowPartialAuth = allowPartialAuth
    }
    
    public static func verify(clientTransactionId: String?,
                              posReferenceNumber: String?,
                              invoiceNumber: String?,
                              operatingUserId: String?,
                              requestMultiUseToken: Bool,
                              allowPartialAuth: Bool?) -> VerifyTransaction {
        return VerifyTransaction(clientTransactionId: clientTransactionId,
                                 posReferenceNumber: posReferenceNumber,
                                 invoiceNumber: invoiceNumber,
                                 operatingUserId: operatingUserId,
                                 cardData: nil,
                                 requestMultiUseToken: requestMultiUseToken,
                                 allowPartialAuth: allowPartialAuth)
    }
    
    public static func verify(clientTransactionId: String?,
                              posReferenceNumber: String?,
                              invoiceNumber: String?,
                              operatingUserId: String?,
                              cardData: ManualCardData,
                              requestMultiUseToken: Bool,
                              allowPartialAuth: Bool?) -> VerifyTransaction {
        var verify = VerifyTransaction(clientTransactionId: clientTransactionId,
                                       posReferenceNumber: posReferenceNumber,
                                       invoiceNumber: invoiceNumber,
                                       operatingUserId: operatingUserId,
                                       cardData: AnyCardData(cardData: cardData),
                                       requestMultiUseToken: requestMultiUseToken,
                                       allowPartialAuth: allowPartialAuth)
        verify.cardholderAddress = cardData.cardHolderAddress

        return verify
    }
}
