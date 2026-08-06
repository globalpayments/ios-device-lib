//
//  GatewayError.swift
//  ios-device-lib
//

import Foundation

public enum GatewayError: Error {
    case hostNotReachable,
    hostTimeout,
    dnsFailed,
    permissionFailed( message: String),
    badRequest(message: String),
    transactionFailed(message: String),
    requestFailed(message: String, errorCode: Int = 0),
    authenticationFail,
    generalError,
    trackReadFail
}

extension GatewayError {
    var description: String {
        switch self {
        case .hostNotReachable:
            return "Host not reachable"
        case .hostTimeout:
            return "Host timeout"
        case .dnsFailed:
            return "DNS failed"
        case .permissionFailed(let message):
            return message
        case .badRequest(let message):
            return message
        case .transactionFailed(let message):
            return message
        case .requestFailed(let message, _):
            return message
        case .generalError:
            return "Some error ocurred"
        case .authenticationFail:
            return "Authentication Fail"
        case .trackReadFail:
            return "Track read fail"
        }
    }
    var errorCode: Int {
        switch self {
        case .requestFailed(_, let errorCode):
            return errorCode
        default:
            return 0
        }
    }
}
