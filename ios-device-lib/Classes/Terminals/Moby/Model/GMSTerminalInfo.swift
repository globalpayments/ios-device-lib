//
//  GMSTerminalInfo.swift
//  ios-device-lib
//

import Foundation

public struct GMSTerminalInfo: InternalTerminalInfo {
    public var name: String
    public var description: String
    public internal(set) var connected = false
    public var terminalType: TerminalType
    public var identifier: UUID
    
    public init(name: String,
         description: String,
         connected: Bool,
         terminalType: TerminalType,
         identifier: UUID) {
        self.name = name
        self.description = description
        self.connected = connected
        self.terminalType = terminalType
        self.identifier = identifier
    }
}
