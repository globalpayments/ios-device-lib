//
//  UpaGetBatchDetail.swift
//  ios-device-lib
//

import Foundation

public struct UpaGetBatchDetail: Codable {
    
    public var message: String
    public let data: UpaBatchCommandData?
    
    public init(message: String = "MSG", data: UpaBatchCommandData?) {
        self.message = message
        self.data = data
    }
}

public struct UpaBatchCommandData: Codable {
    public var command: String
    public let EcrId, requestId: String?
    public let data: UpaBatchData?
    
    public init(command: String = "GetBatchDetails",
                EcrId: String?,
                requestId: String?,
                data: UpaBatchData?) {
        self.command = command
        self.EcrId = EcrId
        self.requestId = requestId
        self.data = data
    }
}

public struct UpaBatchData: Codable {
    public let params: UpaBatchParam?

    public init(params: UpaBatchParam?) {
        self.params = params
    }
}

public struct UpaBatchParam: Codable {
    public var batch: String?
    public var reportOutput: String?
    public var reportType: String?
    
    public init(batch: String? = nil, reportOutput: String? = nil, reportType: String? = nil) {
        self.batch = batch
        self.reportOutput = reportOutput
        self.reportType = reportType
    }
}
