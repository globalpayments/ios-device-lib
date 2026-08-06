//
//  IngenicoMethod.swift
//  ios-device-lib
//

import Foundation

protocol IngenicoMethods: AnyObject {
    init(config terminalConfig: RUATerminalConfig,
         autoConnect: Bool,
         delegate: IngenicoDeviceManagerDelegate)

    func scanForDevices()
    func cancelSearch()
    func connect(_ device: Device)
    func connectToDevice(_ device: RUADevice)
    func disconnect()
    func batteryLevel()
    func startWithTender(_ tender: TerminalTender)
    func confirmAmount(_ confirmed: Bool)
    func selectedAID(_ aid: AID)
    func sendOnlineProcessingResult(_ onlineResult: HostTenderResponse)
    func cancelTransaction()
}
