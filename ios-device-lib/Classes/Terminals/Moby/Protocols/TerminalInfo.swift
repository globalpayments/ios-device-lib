//
//  TerminalInfo.swift
//  ios-device-lib
//

import Foundation

public protocol TerminalInfo: Codable, CustomStringConvertible {
    var name: String { get set }
    var description: String { get set }
    var connected: Bool { get }
    var terminalType: TerminalType { get set }
    var identifier: UUID { get set }

    init(name: String,
         description: String,
         connected: Bool,
         terminalType: TerminalType,
         identifier: UUID)
}

internal protocol InternalTerminalInfo: TerminalInfo {
    var connected: Bool { get set }
    mutating func setConnected(_ connected: Bool)
}

extension InternalTerminalInfo {
    mutating public func setConnected(_ connected: Bool) {
        self.connected = connected
    }
}
