//
//  HostProcessingResult.swift
//  ios-device-lib
//

import Foundation

public struct HostProcessingResult: Codable {
    var transactionState = TransactionStatus.cancelled
    var emvIssuerAuthCode: String?
    var emvIssuerScripts: String?
    public var emvIssuerAuthenticationData: String?
    var emvIssuerResponse: String?
    var gatewayAuthCode: String?
    var gatewayTxnId: String?
    
    enum CodingKeys: String, CodingKey {
        case emvIssuerAuthCode,
        emvIssuerScripts,
        emvIssuerAuthenticationData
    }

    init() {}

    // MARK: Codable
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        emvIssuerAuthCode = try container.decodeIfPresent(String.self, forKey: .emvIssuerAuthCode)
        emvIssuerScripts = try container.decodeIfPresent(String.self, forKey: .emvIssuerScripts)
        emvIssuerAuthenticationData = try container.decodeIfPresent(String.self, forKey: .emvIssuerAuthenticationData)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(emvIssuerAuthCode, forKey: .emvIssuerAuthCode)
        try container.encode(emvIssuerScripts, forKey: .emvIssuerScripts)
        try container.encode(emvIssuerAuthenticationData, forKey: .emvIssuerAuthenticationData)
    }
}

public enum TransactionStatus: UInt, Codable {
    case onlineDecline,
    onlineApproved,
    offlineApproved,
    offlineDecline,
    cancelled,
    hostTimeout,
    gatewayTimeOutNoReply,
    unableToGoOnlineOfflineApproved,
    unableToGoOnlineOfflineDeclined
}
