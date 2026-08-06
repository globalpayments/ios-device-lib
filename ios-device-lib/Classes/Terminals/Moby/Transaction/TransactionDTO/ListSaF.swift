//
//  ListSaF.swift
//  ios-device-lib
//

import Foundation

struct ListSaF: CardTransaction {
    
    var total: UInt?
    var tip: UInt?
    let clientTransactionId: String
    var invoiceNumber: String?
    var posReferenceNumber: String?
    var operatingUserId: String?
    var cardData: AnyCardData?
    var cardholderAddress: Address?
    var allowPartialAuth: Bool?
    var cpcReq: Bool?
    public var isSurchargeEnabled: Bool?
    public var surchargeAmtInfo: String?
    public var surchargeRequested: SurchargeEligibility?
    public var surchargeFee: Decimal?
    
    init(clientTransactionId: String?) {
        if let clientTransactionIdValue = clientTransactionId,
           !clientTransactionIdValue.isEmpty {
            self.clientTransactionId = clientTransactionIdValue
        } else {
            self.clientTransactionId = UUID().uuidString
        }
    }
}
