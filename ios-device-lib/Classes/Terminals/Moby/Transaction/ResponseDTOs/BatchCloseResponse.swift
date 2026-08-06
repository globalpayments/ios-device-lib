//
//  BatchCloseResponse.swift
//  ios-device-lib
//

import Foundation

public struct BatchCloseResponse: TransactionResponse {
    
    // MARK: Variables
    public var transactionResult: TransactionResult? = nil
    public let transactionId: String
    public let gatewayTransactionId: String?
    public var gatewayResponseText: String?
    public var gatewayResponseCode: String?
    public var posReferenceId: String?
    public var operatingUserId: String?
    public var isApproved: Bool
    public var approvedAmount: UInt?
    public var transactionDescription = "Batch Close"
    public var transactionError: GMSError?
    public var emvIssuerRspCode: String?
    public var emvIssuerResponse: String?
    public var authCodeData: String?
    public var clientTxnID: String?
    
    // MARK: Surcharge
    public var surchargeRequested: SurchargeEligibility?
    public var surchargeFee: String?
    public var surchargeAmount: String?

    init(_ transactionId: String) {
        isApproved = false
        gatewayTransactionId = ""
        self.transactionId = transactionId
    }
}
