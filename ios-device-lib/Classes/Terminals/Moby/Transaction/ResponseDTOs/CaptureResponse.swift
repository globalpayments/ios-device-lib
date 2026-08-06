//
//  CaptureResponse.swift
//  ios-device-lib
//

import Foundation

public struct CaptureResponse: GatewayReferenceTransactionResponse {

    // MARK: Constants
    public var transactionResult: TransactionResult? = nil
    public let transactionId: String
    public let gatewayTransactionId: String?
    public var total: UInt?
    public var tax: UInt?
    public var tipAmount: UInt?
    public var taxCategory: TaxCategory?
    public var gatewayResponseText: String?
    public var gatewayResponseCode: String?
    public var posReferenceNumber: String?
    public var transactionHistoryId: String?
    public var invoiceNumber: String?
    public var approvedAmount: UInt?
    public var isPartialApproval: Bool
    public var isApproved: Bool
    public var signatureData: Data?
    public var transactionDescription = "Capture"
    public var transactionError: GMSError?
    public var emvIssuerRspCode: String?
    public var emvIssuerResponse: String?
    public var authCodeData: String?
    public var clientTxnID: String?
    
    // MARK: Surcharge
    public var surchargeRequested: SurchargeEligibility?
    public var surchargeFee: String?
    public var surchargeAmount: String?
    
    init(_ transactionId: String,
         gatewayTransactionId: String?) {
        isApproved = false
        isPartialApproval = false
        self.transactionId = transactionId
        self.gatewayTransactionId = gatewayTransactionId
    }
}
