//
//  HostTenderResponse.swift
//  ios-device-lib
//

import Foundation

@objcMembers
public class HostTenderResponse: NSObject {

    public var tender: TerminalTender?
    public var transactionStatus = TransactionStatus.offlineApproved
    public var emvIssuerAuthCode: String?
    public var emvIssuerScripts: String?
    public var emvIssuerAuthenticationData: String?
    public var emvIssuerRspCode: String?
    public var emvIssuerResponse: String?
    public var gatewayAuthCode: String?
    public var onlineProcessResult: String?
}
