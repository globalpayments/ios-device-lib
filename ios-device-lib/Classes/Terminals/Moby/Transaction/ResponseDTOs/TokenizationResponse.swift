//
//  TokenizationResponse.swift
//  ios-device-lib
//

import Foundation

// TODO: Roadmap Item
public struct TokenizationResponse: TransactionResponse {

    public let transactionId: String
    public var gatewayTransactionId: String?
    public var tokenizedCard: TokenizedCardData?
    public var posReferenceNumber: String?
    public var operatingUserId: String?
    public var invoiceNumber: String?
    public var transactionResult: TransactionResult?
    public var gatewayResponseText: String?
    public var gatewayResponseCode: String?
    public var approvedAmount: UInt?
    public var transactionDescription = "Tokenization"
    public var transactionError: GMSError?
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
        gatewayTransactionId,
        tokenizedCard
    }

    init(_ gatewayTransactionId: String?, transactionId: String) {
        self.transactionId = transactionId
        self.gatewayTransactionId = gatewayTransactionId
    }

    // MARK: Codable
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        transactionId = try container.decode(String.self, forKey: .transactionId)
        gatewayTransactionId = try container.decodeIfPresent(String.self, forKey: .gatewayTransactionId)
        tokenizedCard = try container.decodeIfPresent(TokenizedCardData.self, forKey: .tokenizedCard)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(transactionId, forKey: .transactionId)
        try container.encode(gatewayTransactionId, forKey: .gatewayTransactionId)
        try container.encode(tokenizedCard, forKey: .tokenizedCard)
    }
}
