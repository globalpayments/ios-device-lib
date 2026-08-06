//
//  SaFError.swift
//  ios-device-lib
//

import Foundation

public enum SaFError: Error {
    case writePermissionNotGranted,
    readPermissionNotGranted,
    ioFailed,
    storageFull,
    invalidRequestType,
    transactionInProgress,
    invalidTransactionType
}
