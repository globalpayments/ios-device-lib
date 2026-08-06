//
//  TipAdjustTransaction.swift
//  ios-device-lib
//

import Foundation

/// Tip Adjust Transaction Model, all amounts should be passed in Pennies format (no dollar amounts).
/// Signature not supported for Portico at present.
public struct TipAdjustTransaction: GatewayReferenceTransaction {

    public var total: UInt?
    public var tip: UInt?
    public var invoiceNumber: String?
    public var posReferenceNumber: String?
    public var operatingUserId: String?
    public var gatewayTransactionId: String?
    public let clientTransactionId: String
    public var signatureData: Data?
    public var allowPartialAuth: Bool?
    public var isSurchargeEnabled: Bool?
    public var surchargeAmtInfo: String?
    public var surchargeRequested: SurchargeEligibility?

    private init(clientTransactionId: String?,
                 gatewayTransactionId: String,
                 total: UInt?,
                 tip: UInt?,
                 invoiceNumber: String?,
                 posReferenceNumber: String?,
                 operatingUserId: String?,
                 allowPartialAuth: Bool?,
                 isSurchargeEnabled: Bool?) {
        self.gatewayTransactionId = gatewayTransactionId
        if let clientTransactionIdValue = clientTransactionId, !clientTransactionIdValue.isEmpty {
            self.clientTransactionId = clientTransactionIdValue
        } else {
            self.clientTransactionId = UUID().uuidString
        }
        self.total = total
        self.tip = tip
        self.invoiceNumber = invoiceNumber
        self.operatingUserId = operatingUserId
        self.posReferenceNumber = posReferenceNumber
        self.allowPartialAuth = allowPartialAuth
        self.isSurchargeEnabled = isSurchargeEnabled
    }
    
    public static func tipAdjust(clientTransactionId: String?,
                                 gatewayTransactionId: String,
                                 total: UInt?,
                                 tip: UInt?,
                                 invoiceNumber: String?,
                                 posReferenceNumber: String?,
                                 operatingUserId: String?,
                                 allowPartialAuth: Bool?,
                                 isSurchargeEnabled: Bool?) -> TipAdjustTransaction {
        return TipAdjustTransaction(clientTransactionId: clientTransactionId,
                                    gatewayTransactionId: gatewayTransactionId,
                                    total: total,
                                    tip: tip,
                                    invoiceNumber: invoiceNumber,
                                    posReferenceNumber: posReferenceNumber,
                                    operatingUserId: operatingUserId,
                                    allowPartialAuth: allowPartialAuth,
                                    isSurchargeEnabled: isSurchargeEnabled)
    }
}
