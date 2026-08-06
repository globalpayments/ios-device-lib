//
//  AIDConfiguration.swift
//  ios-device-lib
//

import Foundation

@objcMembers
public class AIDConfiguration: NSObject, Codable {

    public var aid: AID
    public var terminalCapabilities = ""
    public var terminalAppVersion = ""
    public var lowestSupportedICCApplicationVersion = ""
    public var priorityIndex = ""
    public var applicationSelectionFlags = ""
    public var cvmLimit = ""
    public var floorLimit = ""
    public var tlvData = ""
    public var transactionLimit = ""
    public var terminalActionCodeDefault = ""
    public var terminalActionCodeDenial = ""
    public var terminalActionCodeOnline = ""
    public var contactless = false

    public init(aid: AID) {
        self.aid = aid
    }
}
