//
//  ProcessSaFResponse.swift
//  ios-device-lib
//

import Foundation

public struct ProcessSaFResponse: CardTransactionResponse {
    // MARK: CardTransactionResponse Protocol
    var hostProcessingResult: HostProcessingResult?
    public var total: UInt?
    public var tax: UInt?
    public var cardDataSourceType: EntryMode?
    public var cardType: CardType?
    public var maskedPan: String?
    public var aid: String?
    public var applicationLabel: String?
    public var cvm: String?
    public var tsi: String?
    public var tvr: String?
    public var transactionId: String
    public var transactionResult: TransactionResult?
    public var gatewayTransactionId: String?
    public var gatewayResponseText: String?
    public var gatewayResponseCode: String?
    public var approvedAmount: UInt?
    public var cardholderName: String?
    public var manualSignature: Bool?
    public var invoiceNumber: String?
    public var transactionDescription = "SaF Transaction"
    public internal(set) var transactionType: TransactionType?
    public internal(set) var transactionDate: Date?
    public var transactionError: GMSError?
    public var emvIssuerRspCode: String?
    public var emvIssuerResponse: String?
    public var authCodeData: String?
    public var clientTxnID: String?
    
    // MARK: Surcharge
    public var surchargeRequested: SurchargeEligibility?
    public var surchargeFee: String?
    public var surchargeAmount: String?
}
