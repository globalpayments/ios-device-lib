//
//  UpaGetOpenTabDetails.swift
//  ios-device-lib


import Foundation

public struct UpaOpenTabDetails: Codable {
    
    public var message: String
    public let data: UpaOpenTabCommandData?
    
    public init(message: String = "MSG", data: UpaOpenTabCommandData?) {
        self.message = message
        self.data = data
    }
}

public struct UpaOpenTabCommandData: Codable {
    public var command: String
    public let EcrId, requestId: String?
    
    public init(command: String = "GetOpenTabDetails",
                EcrId: String?,
                requestId: String?) {
        self.command = command
        self.EcrId = EcrId
        self.requestId = requestId
    }
}
