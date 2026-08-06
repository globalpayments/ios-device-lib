//
//  VerifyResponse.swift
//  ios-device-lib
//

import Foundation

public struct VerifyResponse: CardTransactionResponse {
    
    // MARK: Variables
    public var transactionResult: TransactionResult?
    public let transactionId: String
    public var approvedAmount: UInt?
    public var total: UInt?
    public var tax: UInt?
    public var tip: UInt?
    public let gatewayTransactionId: String?
    public var posReferenceNumber: String?
    public var forcedAuthCode: String?
    public var invoiceNumber: String?
    public var operatingUserId: String?
    public var cardholderName: String?
    public var cardDataSourceType: EntryMode?
    public var cardType: CardType?
    public var gatewayResponseText: String?
    public var gatewayResponseCode: String?
    public var authCode: String?
    public var cvvResponseCode: String?
    public var cvvResponseMessage: String?
    public var avsResponseCode: String?
    public var avsResponseMessage: String?
    public var maskedPan: String?
    public var isPartialApproval: Bool
    public var isApproved: Bool
    public var cpcInd: String?
    public var referenceNumber: String?
    public var availableBalance: UInt?
    public var recurringDataCode: String?
    public var hostRspDateTime: String?
    public var tokenizedCard: TokenizedCardData?
    var hostProcessingResult: HostProcessingResult?
    public var aid: String?
    public var applicationLabel: String?
    public var cvm: String?
    public var tsi: String?
    public var tvr: String?
    public var transactionDescription = "Verify"
    public var transactionError: GMSError?
    public var duplicateData: DuplicateDataResponse?
    public var emvIssuerRspCode: String?
    public var emvIssuerResponse: String?
    public var authCodeData: String?
    public var clientTxnID: String?
    
    // MARK: Surcharge
    public var surchargeRequested: SurchargeEligibility?
    public var surchargeFee: String?
    public var surchargeAmount: String?
    
    enum CodingKeys: String, CodingKey {
           case transactionId,
                isApproved,
                isPartialApproval,
                gatewayTransactionId
    }

    init(_ transactionId: String,
           gatewayTransactionId: String?) {
            isApproved = false
            isPartialApproval = false
            self.transactionId = transactionId
            self.gatewayTransactionId = gatewayTransactionId
       }
    
    // MARK: Codable
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        transactionId = try container.decode(String.self, forKey: .transactionId)
        gatewayTransactionId = try container.decodeIfPresent(String.self, forKey: .gatewayTransactionId)
        isApproved = try container.decodeIfPresent(Int.self, forKey: .isApproved) == 1
        isPartialApproval = try container.decodeIfPresent(Int.self, forKey: .isPartialApproval) == 1
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(transactionId, forKey: .transactionId)
        try container.encode(isApproved, forKey: .isApproved)
        try container.encode(isPartialApproval, forKey: .isPartialApproval)
        try container.encode(gatewayTransactionId, forKey: .gatewayTransactionId)
    }

}

