//
//  ReturnTransaction.swift
//  ios-device-lib
//

import Foundation

/// Return Transaction Model, all amounts should be passed in Pennies format (no dollar amounts).
public struct ReturnTransaction: CardTransaction, GatewayReferenceTransaction {

    public var total: UInt?
    public var tip: UInt?
    public let clientTransactionId: String
    public internal(set) var tax: UInt?
    public var posReferenceNumber: String?
    public var invoiceNumber: String?
    public var operatingUserId: String?
    public internal(set) var cardData: AnyCardData?
    public let taxCategory: TaxCategory?
    public var gatewayTransactionId: String?
    public var cardholderAddress: Address?
    public var allowPartialAuth: Bool?
    public var cpcReq: Bool?
    public var isSurchargeEnabled: Bool?
    public var surchargeAmtInfo: String?
    public var surchargeRequested: SurchargeEligibility?
    public var surchargeFee: Decimal?
    
    private init(clientTransactionId: String?,
                 total: UInt?,
                 tax: UInt?,
                 tip: UInt?,
                 taxCategory: TaxCategory?,
                 gatewayTransactionId: String?,
                 posReferenceNumber: String?,
                 invoiceNumber: String?,
                 operatingUserId: String?,
                 cardData: AnyCardData?,
                 allowPartialAuth: Bool?) {
        self.total = total
        self.tax = tax
        self.tip = tip
        self.taxCategory = taxCategory
        self.gatewayTransactionId = gatewayTransactionId
        self.posReferenceNumber = posReferenceNumber
        self.invoiceNumber = invoiceNumber
        self.operatingUserId = operatingUserId
        self.cardData = cardData
        self.allowPartialAuth = allowPartialAuth
        if let clientTransactionIdValue = clientTransactionId, !clientTransactionIdValue.isEmpty {
            self.clientTransactionId = clientTransactionIdValue
        } else {
            self.clientTransactionId = UUID().uuidString
        }
    }
    
    public static func returnWithReference(clientTransactionId: String?,
                                           total: UInt?,
                                           tax: UInt?,
                                           tip: UInt?,
                                           taxCategory: TaxCategory?,
                                           gatewayTransactionId: String?,
                                           posReferenceNumber: String?,
                                           invoiceNumber: String?,
                                           operatingUserId: String?,
                                           allowPartialAuth: Bool?) -> ReturnTransaction {
        return ReturnTransaction(clientTransactionId: clientTransactionId,
                                 total: total,
                                 tax: tax,
                                 tip: tip,
                                 taxCategory: taxCategory,
                                 gatewayTransactionId: gatewayTransactionId,
                                 posReferenceNumber: posReferenceNumber,
                                 invoiceNumber: invoiceNumber,
                                 operatingUserId: operatingUserId,
                                 cardData: nil,
                                 allowPartialAuth: allowPartialAuth)
    }
    
    public static func returnWithManualCard(clientTransactionId: String?,
                                            total: UInt?,
                                            tax: UInt?,
                                            tip: UInt?,
                                            taxCategory: TaxCategory?,
                                            posReferenceNumber: String?,
                                            invoiceNumber: String?,
                                            operatingUserId: String?,
                                            cardData: ManualCardData,
                                            allowPartialAuth: Bool?) -> ReturnTransaction {
        var refund = ReturnTransaction(clientTransactionId: clientTransactionId,
                                       total: total,
                                       tax: tax,
                                       tip: tip,
                                       taxCategory: taxCategory,
                                       gatewayTransactionId: nil,
                                       posReferenceNumber: posReferenceNumber,
                                       invoiceNumber: invoiceNumber,
                                       operatingUserId: operatingUserId,
                                       cardData: AnyCardData(cardData: cardData),
                                       allowPartialAuth: allowPartialAuth)
        refund.cardholderAddress = cardData.cardHolderAddress

        return refund
    }
    
    public static func returnWithCard(clientTransactionId: String?,
                                      total: UInt?,
                                      tax: UInt?,
                                      tip: UInt?,
                                      taxCategory: TaxCategory?,
                                      posReferenceNumber: String?,
                                      invoiceNumber: String?,
                                      operatingUserId: String?,
                                      allowPartialAuth: Bool?) -> ReturnTransaction {
        return ReturnTransaction(clientTransactionId: clientTransactionId,
                                 total: total,
                                 tax: tax,
                                 tip: tip,
                                 taxCategory: taxCategory,
                                 gatewayTransactionId: nil,
                                 posReferenceNumber: posReferenceNumber,
                                 invoiceNumber: invoiceNumber,
                                 operatingUserId: operatingUserId,
                                 cardData: nil,
                                 allowPartialAuth: allowPartialAuth)
    }
}
