//
//  Transaction.swift
//  ios-device-lib
//

import Foundation

public protocol Transaction: Codable {
    var clientTransactionId: String { get }
    var invoiceNumber: String? { get set }
    var posReferenceNumber: String? { get set }
    var operatingUserId: String? { get set }
    var isSurchargeEnabled: Bool? { get set }
    var surchargeAmtInfo: String? { get set }
}

protocol CardTransaction: Transaction {
    var total: UInt? { get set }
    var tip: UInt? { get set }
    var cardData: AnyCardData? { get set }
    var cardholderAddress: Address? { get set }
    var allowPartialAuth: Bool? { get set }
    var cpcReq: Bool? { get set }
    var surchargeRequested: SurchargeEligibility? { get set }
    var surchargeFee: Decimal? { get set }
}

protocol GatewayReferenceTransaction: Transaction {
    var total: UInt? { get set }
    var tip: UInt? { get set }
    var gatewayTransactionId: String? { get set }
}
