//
//  TerminalOTAManagerDelegate.swift
//  ios-device-lib
//

import Foundation

public protocol TerminalOTAManagerDelegate {
    func terminalVersionDetails(info: [AnyHashable : Any]?)
    func terminalOTAResult(resultType: TerminalOTAResult, info: [String: AnyObject]?, error:
    Error?)
    func listOfVersionsFor(type: TerminalOTAUpdateType, results: [Any]?)
    func otaUpdateProgress(percentage: Float)
    func onReturnSetTargetVersion(resultType: TerminalOTAResult, type: TerminalOTAUpdateType, message: String)
    func onError(error: ConnectionError)
}
