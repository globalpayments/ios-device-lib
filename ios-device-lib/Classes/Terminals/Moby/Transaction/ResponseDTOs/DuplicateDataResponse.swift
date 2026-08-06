//
//  DuplicateDataResponse.swift
//  ios-device-lib
//

import Foundation
import GlobalPaymentsApi

public struct DuplicateDataResponse {
    public var transactionId: String?
    public var hostResponseDate: String?
    public var clientTransactionId: String?
    public var uniqueDeviceId: String?
    public var globalTransactionId: String?
    public var authorizationCode: String?
    public var referenceNumber: String?
    public var authorizedAmount: String?
    public var cardType: String?
    public var cardLast4: String?

    init(from duplicateData: GPDuplicateData) {
        self.transactionId = duplicateData.transactionId
        self.hostResponseDate = duplicateData.hostResponseDate
        self.clientTransactionId = duplicateData.clientTransactionId
        self.uniqueDeviceId = duplicateData.uniqueDeviceId
        self.globalTransactionId = duplicateData.globalTransactionId
        self.authorizationCode = duplicateData.authorizationCode
        self.referenceNumber = duplicateData.referenceNumber
        self.authorizedAmount = duplicateData.authorizedAmount
        self.cardType = duplicateData.cardType
        self.cardLast4 = duplicateData.cardLast4
    }
}
