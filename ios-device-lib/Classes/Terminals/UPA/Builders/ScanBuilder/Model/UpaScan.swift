//
//  UpaScan.swift
//  ios-device-lib
//

import Foundation

public struct UpaScan: Codable {
    public var message: String
    public let data: UpaCommandData?
    
    public init(message: String = "MSG", data: UpaCommandData?) {
        self.message = message
        self.data = data
    }
}

public struct UpaCommandData: Codable {
    public var command: String
    public let EcrId, requestId: String?
    public let timeOut: TimeInterval?
    public let data: UpaScanData?
    
    public init(command: String = "Scan", EcrId: String?,
                requestId: String?, timeOut: TimeInterval? = nil, data: UpaScanData?) {
        self.command = command
        self.EcrId = EcrId
        self.requestId = requestId
        self.timeOut = timeOut
        self.data = data
    }
}

public struct UpaScanData: Codable {
    public let params: UpaScanParam?

    public init(params: UpaScanParam?) {
        self.params = params
    }
}

public struct UpaScanParam: Codable {
    public let header, prompt1, prompt2: String?
    public let displayOption: DisplayOption?
    
    public init(header: String? = nil, prompt1: String? = nil, prompt2: String? = nil, displayOption: DisplayOption? = nil) {
        self.header = header
        self.prompt1 = prompt1
        self.prompt2 = prompt2
        self.displayOption = displayOption
    }
}

public enum DisplayOption: Int, Codable {
    case NO_SCREEN_CHANGE = 0
    case RETURN_TO_IDLE_SCREEN
}
