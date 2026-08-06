//
//  CaptureTransaction.swift
//  ios-device-lib
//

import Foundation

/// Capture Transaction Model, all amounts should be passed in Pennies format (no dollar amounts).
/// Signature not supported for Portico at present.
public struct CaptureTransaction: GatewayReferenceTransaction {

    public var gatewayTransactionId: String?
    public let clientTransactionId: String
    public var total: UInt?
    public var tax: UInt?
    public var tip: UInt?
    public let taxCategory: TaxCategory?
    public var operatingUserId: String?
    public var posReferenceNumber: String?
    public var invoiceNumber: String?
    public var signatureData: Data?
    public var customerReceiptEmail: String?
    public var isSurchargeEnabled: Bool?
    public var surchargeAmtInfo: String?
    public var surchargeFee: Decimal?
    public var preTaxAmount: Decimal?

    private init(clientTransactionId: String?,
                 gatewayTransactionId: String,
                 total: UInt?,
                 tax: UInt?,
                 tip: UInt?,
                 taxCategory: TaxCategory?,
                 invoiceNumber: String?,
                 posReferenceNumber: String?,
                 operatingUserId: String?) {
        self.gatewayTransactionId = gatewayTransactionId
        if let clientTransactionIdValue = clientTransactionId, !clientTransactionIdValue.isEmpty {
            self.clientTransactionId = clientTransactionIdValue
        } else {
            self.clientTransactionId = UUID().uuidString
        }
        self.total = total
        self.tax = tax
        self.tip = tip
        self.taxCategory = taxCategory
        self.invoiceNumber = invoiceNumber
        self.posReferenceNumber = posReferenceNumber
        self.operatingUserId = operatingUserId
    }

    public static func capture(clientTransactionId:String?,
                               gatewayTransactionId: String,
                               total: UInt?,
                               tax: UInt?,
                               tip: UInt?,
                               taxCategory: TaxCategory?,
                               invoiceNumber: String?,
                               posReferenceNumber: String?,
                               operatingUserId: String?) -> CaptureTransaction {
        return CaptureTransaction(clientTransactionId: clientTransactionId,
                                  gatewayTransactionId: gatewayTransactionId,
                                  total: total,
                                  tax: tax,
                                  tip: tip,
                                  taxCategory: taxCategory,
                                  invoiceNumber: invoiceNumber,
                                  posReferenceNumber: posReferenceNumber,
                                  operatingUserId: operatingUserId)
    }
}
