//
//  TerminalConfig.swift
//  ios-device-lib
//

import Foundation

public struct TerminalConfig: Codable, Equatable {

    // MARK: Constants
    public let terminalType: TerminalType
    public let autoConnect: Bool
    public let gatewayType: GatewayType
    let contactAIDs: [AIDConfiguration]?
    let contactLessAIDs: [AIDConfiguration]?
    let entryModes: [EntryMode]
    let timeout: UInt
    let emvTerminalConfig: EMVTerminalConfiguration?
    var terminalOnlineProcessTimeout: UInt?
    var otaServerUrl: String = ""
    var supportsOTAUpdate: Bool = false

    public static func == (lhs: TerminalConfig, rhs: TerminalConfig) -> Bool {
        return true
    }
}
