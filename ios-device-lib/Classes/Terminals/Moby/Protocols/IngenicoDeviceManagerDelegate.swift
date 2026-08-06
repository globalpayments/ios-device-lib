//
//  IngenicoDeviceManagerInterface.swift
//  ios-device-lib
//

import Foundation

public protocol IngenicoDeviceManagerDelegate: NSObject {
    func devicesFound(_ devices: [Device]?)
    func deviceError(_ error: Error)
    func deviceConnected()
    func deviceDisconnected()
    func onDeviceConfigurationProgress(_ completed: Int, total progressTotal: Int, isFailed: Bool)
    func onTransactionStatus(_ status: ProgressMessage, withIngenicoResponse response: TerminalTender?)
    func selectAid(_ aids: [AID]?)
    func transactionError(_ error: Error)
}
