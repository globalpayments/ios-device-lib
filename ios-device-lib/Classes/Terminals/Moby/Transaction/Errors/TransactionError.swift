//
//  TransactionError.swift
//  ios-device-lib
//

import Foundation

public enum TransactionError: Error {
    case gatewayNotConfigured,
    terminalNotConfigured,
    bluetoothNotSupported,
    bluetoothPermissionNotGranted,
    bluetoothDisabled,
    bluetoothConnectionLost,
    devicePoweredOff,
    cardNotRemoved,
    trackReadFailed,
    terminalNotConnnected,
    transactionNotInProgress,
    transactionNotSupported,
    transactionInProgress,
    transactionFailed(message: String),
    safTransactionFailed(message: String, transactionID: String?),
    terminalFailed(message: String, errorCode: Int = 0),
    missingRequiredValue(message: String),
    gatewayPermissionFailed(message: String),
    gatewayFailure(message: String, errorCode: Int = 0),
    hostTimeout,
    hostNotReachable
}

public struct GMSError: Error, Codable {

    var errorDomain: String             // NSURLErrorDomain
    var errorCode: Int                  // NSError Code
    var localizedDescription: String    // NSError localizedDescription
}
