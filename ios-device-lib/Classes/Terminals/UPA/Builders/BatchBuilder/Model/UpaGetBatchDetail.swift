//
//  UpaGetBatchDetail.swift
//  ios-device-lib
//

import Foundation

// MARK: - TYP Report Enums

/// Determines the type of batch report requested from the UPA device.
/// Maps to the `reportType` parameter in the GetBatchDetails command.
public enum UpaReportType: String {
    /// Prints a summary report. Sends `"summary"` to the device.
    case summary
    /// Prints a detailed report. Sends `"detail"` to the device.
    case detail
}

/// Determines the filter applied when printing UPA batch reports.
/// Maps to the `reportSubType` parameter in the GetBatchDetails command.
public enum UpaReportSubType: String {
    /// Filter reports by reference number. Sends `"1"` to the device.
    case byReference     = "1"
    /// Filter reports by clerk. Sends `"2"` to the device.
    case byClerk         = "2"
    /// Filter reports by all clerks. Sends `"3"` to the device.
    case byAllClerks     = "3"
}

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
    public var reportSubType: String?
    public var bothReports: String?
    public var clerkId: String?
    public var previousBatchReport: String?

    public init(batch: String? = nil,
                reportOutput: String? = nil,
                reportType: String? = nil,
                reportSubType: String? = nil,
                bothReports: String? = nil,
                clerkId: String? = nil,
                previousBatchReport: String? = nil) {
        self.batch = batch
        self.reportOutput = reportOutput
        self.reportType = reportType
        self.reportSubType = reportSubType
        self.bothReports = bothReports
        self.clerkId = clerkId
        self.previousBatchReport = previousBatchReport
    }

    /// Typed convenience initialiser — accepts `UpaReportType` and `UpaReportSubType` enums
    /// and `Bool?` for `bothReports`/`previousBatchReport` instead of raw strings.
    public static func make(batch: String? = nil,
                            reportOutput: String? = nil,
                            reportType: UpaReportType? = nil,
                            reportSubType: UpaReportSubType? = nil,
                            bothReports: Bool? = nil,
                            clerkId: String? = nil,
                            previousBatchReport: Bool? = nil) -> UpaBatchParam {
        UpaBatchParam(
            batch: batch,
            reportOutput: reportOutput,
            reportType: reportType?.rawValue,
            reportSubType: reportSubType?.rawValue,
            bothReports: bothReports.map { $0 ? "1" : "0" },
            clerkId: clerkId,
            previousBatchReport: previousBatchReport.map { $0 ? "1" : "0" }
        )
    }
}
