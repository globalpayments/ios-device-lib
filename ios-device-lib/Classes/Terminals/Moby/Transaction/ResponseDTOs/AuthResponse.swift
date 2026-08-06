//
//  AuthResponse.swift
//  ios-device-lib
//

import Foundation

public struct AuthResponse: CardTransactionResponse {

    // MARK: Constants
    public var transactionResult: TransactionResult? = nil
    public var total: UInt?
    public var tax: UInt?
    public var tip: UInt?
    public var taxCategory: TaxCategory?
    public var posReferenceNumber: String?
    public var invoiceNumber: String?
    public var operatingUserId: String?
    public var cardholderName: String?
    public var cardDataSourceType: EntryMode?
    public var cardType: CardType?
    public let gatewayTransactionId: String?
    public var gatewayResponseText: String?
    public var gatewayResponseCode: String?
    public var authCode: String?
    public var cvvResponseCode: String?
    public var cvvResponseMessage: String?
    public var avsResponseCode: String?
    public var avsResponseMessage: String?
    public var maskedPan: String?
    public var aid: String?
    public var applicationLabel: String?
    public var cvm: String?
    public var tsi: String?
    public var tvr: String?
    public var iac: String?
    public var iad: String?
    public var applicationCryptogram: String?
    public var applicationCryptogramType: String?
    public var applicationPANSequenceNumber: String?
    public var applicationVersionNumber: String?
    public var cid: String?
    public var applicationTransactionCounter: String?
    public var unpredictableNumber: String?
    public var transactionSequenceCounter: String?
    public var transactionHistoryId: String?
    public var approvedAmount: UInt?
    public var tipAmount: UInt?
    public var isPartialApproval: Bool
    public var isApproved: Bool
    public var avsResult: String?
    public var tokenizedCard: TokenizedCardData?
    public internal(set) var transactionType: TransactionType?
    var terminalType: String?
    var merchantName: String = ""
    var merchantAddress: String = ""
    var merchantNumber: String = ""
    var manualSignature: Bool = true
    internal var signatureAgreement: String = ""
    internal var acknowledgement: String = ""
    internal var refundPolicy: String = ""
    public var transactionDescription = "Auth"
    public var transactionError: GMSError?
    public var duplicateData: DuplicateDataResponse?
    public var emvIssuerRspCode: String?
    public var emvIssuerResponse: String?
    public var authCodeData: String?
    public var clientTxnID: String?

    // MARK: EMVTransactionResponse Protocol
    public let transactionId: String
    public var hostProcessingResult: HostProcessingResult?
    
    // MARK: Surcharge
    public var surchargeRequested: SurchargeEligibility?
    public var surchargeFee: String?
    public var surchargeAmount: String?

    enum CodingKeys: String, CodingKey {
        case transactionId,
        gatewayTransactionId,
        isPartialApproval,
        isApproved,
        hostProcessingResult
    }

    init(_ transactionId: String,
         gatewayTransactionId: String?) {
        isApproved = false
        isPartialApproval = false
        self.transactionId = transactionId
        self.gatewayTransactionId = gatewayTransactionId
    }

    // MARK: Codable
    // TODO: Implementation
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        transactionId = try container.decode(String.self, forKey: .transactionId)
        gatewayTransactionId = try container.decodeIfPresent(String.self, forKey: .gatewayTransactionId)
        isPartialApproval = try container.decodeIfPresent(Int.self, forKey: .isPartialApproval) == 1
        isApproved = try container.decodeIfPresent(Int.self, forKey: .isApproved) == 1
        hostProcessingResult = try container.decode(HostProcessingResult.self, forKey: .hostProcessingResult)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(transactionId, forKey: .transactionId)
        try container.encode(gatewayTransactionId, forKey: .gatewayTransactionId)
        try container.encode(isPartialApproval, forKey: .isPartialApproval)
        try container.encode(isApproved, forKey: .isApproved)
        try container.encode(hostProcessingResult, forKey: .hostProcessingResult)
    }
}
