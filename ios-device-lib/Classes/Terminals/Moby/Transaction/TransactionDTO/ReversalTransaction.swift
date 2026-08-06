//
//  ReversalTransaction.swift
//  ios-device-lib
//

import Foundation

/// Reversal Transaction Model, all amounts should be passed in Pennies format (no dollar amounts).
public struct ReversalTransaction: CardTransaction, GatewayReferenceTransaction {

    public var invoiceNumber: String?
    public var operatingUserId: String?
    public var posReferenceNumber: String?
    public internal(set) var cardData: AnyCardData?
    public let clientTransactionId: String
    public var total: UInt?
    public var tip: UInt?
    public var gatewayTransactionId: String?
    public var reversalReason: ReversalReason = .undefined
    var tlv: String?
    public var cardholderAddress: Address?
    public var allowPartialAuth: Bool?
    public var cpcReq: Bool?
    public var isSurchargeEnabled: Bool?
    public var surchargeAmtInfo: String?
    public var surchargeRequested: SurchargeEligibility?
    public var surchargeFee: Decimal?
    
    private init(clientTransactionId: String?,
                 gatewayTransactionId: String?,
                 reversalReason: ReversalReason,
                 posReferenceNumber: String?,
                 tlv: String?,
                 amount: UInt,
                 cardData: AnyCardData?,
                 allowPartialAuth: Bool?) {
        if let clientTransactionIdValue = clientTransactionId, !clientTransactionIdValue.isEmpty {
            self.clientTransactionId = clientTransactionIdValue
        } else {
            self.clientTransactionId = UUID().uuidString
        }
        self.gatewayTransactionId = gatewayTransactionId
        self.reversalReason = reversalReason
        self.posReferenceNumber = posReferenceNumber
        self.cardData = cardData
        self.tlv = tlv
        self.total = amount
        self.allowPartialAuth = allowPartialAuth
    }
    
    public static func reversal(clientTransactionId: String?,
                                gatewayTransactionId: String?,
                                reversalReason: ReversalReason,
                                posReferenceNumber: String?,
                                amount: UInt,
                                tlv: String?,
                                allowPartialAuth: Bool?) -> ReversalTransaction {
        return ReversalTransaction(clientTransactionId: clientTransactionId,
                                   gatewayTransactionId: gatewayTransactionId,
                                   reversalReason: reversalReason,
                                   posReferenceNumber: posReferenceNumber,
                                   tlv: tlv,
                                   amount: amount,
                                   cardData: nil,
                                   allowPartialAuth: allowPartialAuth)
    }
}
