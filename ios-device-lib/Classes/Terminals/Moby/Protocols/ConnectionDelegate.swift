//
//  ConnectionDelegate.swift
//  ios-device-lib
//

import Foundation

public protocol ConnectionDelegate: AnyObject {
    func onConnected(terminalInfo: TerminalInfo)
    func onDisconnected(terminalInfo: TerminalInfo)
    func configuringTerminal(state: TransactionState)
    func onError(error: ConnectionError)
}
