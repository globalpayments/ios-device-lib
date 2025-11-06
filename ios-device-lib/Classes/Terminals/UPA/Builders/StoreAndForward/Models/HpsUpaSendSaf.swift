//
//  HpsUpaSendSaf.swift
//  ios-device-lib
//

import Foundation

struct HpsUpaSendSafConstants {
    static let command = "SendSAF"
}

// MARK: - HpsUpaSendSaf

public struct HpsUpaSendSaf: Codable {
    public let message: String?
    public let data: HpsUpaCommandPayloadNoData?

    public init(message: String? = "MSG", data: HpsUpaCommandPayloadNoData?) {
        self.message = message
        self.data = data
    }
}
