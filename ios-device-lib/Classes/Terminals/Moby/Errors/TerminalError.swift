//
//  TerminalError.swift
//  ios-device-lib
//

import Foundation

enum TerminalError: Error {
    case bluetoothNotSupported,
    bluetoothPermissionNotGranted,
    bluetoothDisabled,
    bluetoothConnectionLost,
    devicePoweredOff,
    terminalNotConfigured,
    commandFailed,
    timeout,
    invalidEntryModes,
    transactionFailed(message: String, errorCode: Int = 0),
    cardNotRemoved

    var errorDescription: String? {
            switch self {
            case let .transactionFailed(message, _):
                return message
            default:
                return "\(self)"
            }
    }

    func transcationError() -> TransactionError {
        switch self {
        case .cardNotRemoved:
            return .cardNotRemoved
        case .transactionFailed(let message, let errorCode):
            return .terminalFailed(message: message, errorCode: errorCode)
        default:
            return .terminalNotConnnected
        }
    }
}

extension Error {
    var errorCode: Int? {
        return (self as NSError).code
    }
}
