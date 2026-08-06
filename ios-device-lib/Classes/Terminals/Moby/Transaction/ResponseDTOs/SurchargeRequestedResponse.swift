//
//  SurchargeRequestedResponse.swift
//  ios-device-lib
//

import Foundation

public struct SurchargeRequestedResponse: TransactionResponse {
    
    public var transactionResult: TransactionResult?
    public var gatewayResponseText: String?
    public var gatewayResponseCode: String?
    public var approvedAmount: UInt?
    public var transactionDescription: String
    public var transactionError: GMSError?
    public var clientTxnID: String?

    public let transactionId: String
    public var gatewayTransactionId: String?
    public var tokenizedCard: TokenizedCardData?
    public var surchargeRequested: SurchargeEligibility?
    public var surchargeFee: String?
    public var surchargeAmount: String?

    enum CodingKeys: String, CodingKey {
        case transactionId,
             gatewayTransactionId,
             tokenizedCard,
             surchargeRequested,
             surchargeFee,
             
             transactionResult,
             gatewayResponseText,
             gatewayResponseCode,
             approvedAmount,
             transactionDescription,
             transactionError
    }
    
    init(_ gatewayTransactionId: String?, transactionId: String, surchargeRequested: SurchargeEligibility?, surchargeFee: String?,
         tokenizedCard: TokenizedCardData?, transactionResult: TransactionResult?,
         gatewayResponseText: String?, gatewayResponseCode: String?, approvedAmount: UInt?,
         transactionDescription: String, transactionError: GMSError?) {
        
        self.transactionId = transactionId
        self.gatewayTransactionId = gatewayTransactionId
        self.surchargeRequested = surchargeRequested
        self.surchargeFee = surchargeFee
        self.tokenizedCard = tokenizedCard
        self.transactionResult = transactionResult
        self.gatewayResponseText = gatewayResponseText
        self.gatewayResponseCode = gatewayResponseCode
        self.approvedAmount = approvedAmount
        self.transactionDescription = transactionDescription
        self.transactionError = transactionError
    }

    // MARK: Codable
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        transactionId = try container.decode(String.self, forKey: .transactionId)
        gatewayTransactionId = try container.decodeIfPresent(String.self, forKey: .gatewayTransactionId)
        tokenizedCard = try container.decodeIfPresent(TokenizedCardData.self, forKey: .tokenizedCard)
        surchargeRequested = try container.decodeIfPresent(SurchargeEligibility.self,
                                                           forKey: .surchargeRequested)
        
        transactionResult = try container.decodeIfPresent(TransactionResult.self, forKey: .transactionResult)
        gatewayResponseText = try container.decodeIfPresent(String.self, forKey: .gatewayResponseText)
        gatewayResponseCode = try container.decodeIfPresent(String.self, forKey: .gatewayResponseCode)
        approvedAmount = try container.decodeIfPresent(UInt.self, forKey: .approvedAmount)
        transactionDescription = try container.decodeIfPresent(String.self, forKey: .transactionDescription) ?? ""
        transactionError = try container.decodeIfPresent(GMSError.self, forKey: .transactionError)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(transactionId, forKey: .transactionId)
        try container.encode(gatewayTransactionId, forKey: .gatewayTransactionId)
        try container.encode(tokenizedCard, forKey: .tokenizedCard)
        try container.encode(surchargeRequested, forKey: .surchargeRequested)
    }
}
