//
//  VoidTransaction.swift
//  ios-device-lib
//

import Foundation

/// Void Transaction Model, all amounts should be passed in Pennies format (no dollar amounts).
public struct VoidTransaction: GatewayReferenceTransaction {
    
    public var operatingUserId: String?
    public var total: UInt?
    public var tip: UInt?
    public let clientTransactionId: String
    public var invoiceNumber: String?
    public let reversalReason: ReversalReason
    public var posReferenceNumber: String?
    public var gatewayTransactionId: String?
    public var allowPartialAuth: Bool?
    public var isSurchargeEnabled: Bool?
    public var surchargeAmtInfo: String?

    private init(clientTransactionId: String?,
                 gatewayTransactionId: String?,
                 reversalReason: ReversalReason,
                 posReferenceNumber: String?,
                 invoiceNumber: String?,
                 operatingUserId: String?,
                 allowPartialAuth: Bool?) {
        self.gatewayTransactionId = gatewayTransactionId
        self.reversalReason = reversalReason
        self.posReferenceNumber = posReferenceNumber
        self.invoiceNumber = invoiceNumber
        if let clientTransactionIdValue = clientTransactionId, !clientTransactionIdValue.isEmpty {
            self.clientTransactionId = clientTransactionIdValue
        } else {
            self.clientTransactionId = UUID().uuidString
        }
        self.operatingUserId = operatingUserId
        self.allowPartialAuth = allowPartialAuth
    }

    public static func void(clientTransactionId: String?,
                            gatewayTransactionId: String,
                            reversalReason: ReversalReason,
                            posReferenceNumber: String?,
                            invoiceNumber: String?,
                            operatingUserId: String?,
                            allowPartialAuth: Bool?) -> VoidTransaction {
        return VoidTransaction(clientTransactionId: clientTransactionId,
                               gatewayTransactionId: gatewayTransactionId,
                               reversalReason: reversalReason,
                               posReferenceNumber: posReferenceNumber,
                               invoiceNumber: invoiceNumber,
                               operatingUserId: operatingUserId,
                               allowPartialAuth: allowPartialAuth)
    }
}
