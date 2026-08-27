//
//  GMSDeviceReconnectionInterface.swift
//  ios-device-lib
//

import Foundation

protocol GMSDeviceReconnectionInterface {
    func hasSavedDevice(_ terminalType: TerminalType) -> Bool
    func reconnectLastDevice(_ terminalType: TerminalType, connectingFinishBlock : @escaping (Bool?) -> Void)
}
