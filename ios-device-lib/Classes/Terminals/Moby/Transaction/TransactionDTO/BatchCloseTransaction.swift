//
//  BatchCloseTransaction.swift
//  ios-device-lib
//

import Foundation

public struct BatchCloseTransaction: Transaction {

    public var operatingUserId: String?
    public let clientTransactionId: String
    public var invoiceNumber: String?
    public var posReferenceNumber: String?
    public var isSurchargeEnabled: Bool?
    public var surchargeAmtInfo: String?

    private init(clientTransactionId: String?,
                 operatingUserId: String?) {
        self.operatingUserId = operatingUserId
        if let clientTransactionIdValue = clientTransactionId, !clientTransactionIdValue.isEmpty {
            self.clientTransactionId = clientTransactionIdValue
        } else {
            self.clientTransactionId = UUID().uuidString
        }
    }
    
    public static func batchClose(clientTransactionId: String?,
                                  operatingUserId: String?) -> BatchCloseTransaction {
        return BatchCloseTransaction(clientTransactionId: clientTransactionId,
                                     operatingUserId: operatingUserId)
    }
}
