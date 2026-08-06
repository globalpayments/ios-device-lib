//
//  RUATerminalConfig.swift
//  ios-device-lib
//

import Foundation

@objcMembers
public class RUATerminalConfig: NSObject {

    // Variables
    public var isDebug = true
    public var isProduction = false
    public var terminalType: RUATerminalType = .unknown
    public var emvConfig: EMVTerminalConfiguration?
    public var connectionInterface: RUACommunicationInterface?

    // Init
    public init(isDebug: Bool,
                isProduction: Bool,
                terminal: RUATerminalType,
                emvConfig: EMVTerminalConfiguration?,
                connectionInterface: RUACommunicationInterface? = nil) {
        super.init()

        self.isDebug = isDebug
        self.isProduction = isProduction
        self.terminalType = terminal
        self.emvConfig = emvConfig
        self.connectionInterface = connectionInterface ?? RUACommunicationInterfaceBluetooth
    }
}
