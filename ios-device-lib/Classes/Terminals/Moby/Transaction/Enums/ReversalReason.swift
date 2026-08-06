//
//  ReversalResaon.swift
//  ios-device-lib
//

import Foundation

public enum ReversalReason: Int, CaseIterable, Codable {
    case undefined,
         voidedByCustomer,
         deviceTimeOut,
         deviceUnavailable,
         partialReversal,
         prematureChipRemoval,
         chipDeclined,
         surchargeRequested

    public typealias RawValue = String

    public var rawValue: RawValue {
        switch self {
        case .undefined:
            return "undefined"
        case .voidedByCustomer:
            return "voidedByCustomer"
        case .deviceTimeOut:
            return "deviceTimeOut"
        case .deviceUnavailable:
            return "deviceUnavailable"
        case .partialReversal:
            return "partialReversal"
        case .prematureChipRemoval:
            return "prematureChipRemoval"
        case .chipDeclined:
            return "chipDeclined"
        case .surchargeRequested:
            return "surchargeRequested"
        }
    }

    public init?(rawValue: RawValue) {
        switch rawValue {
        case "undefined":
            self = .undefined
        case "voidedByCustomer":
            self = .voidedByCustomer
        case "deviceTimeOut":
            self = .deviceTimeOut
        case "deviceUnavailable":
            self = .deviceUnavailable
        case "partialReversal":
            self = .partialReversal
        case "prematureChipRemoval":
            self = .prematureChipRemoval
        case "chipDeclined":
            self = .chipDeclined
        case "surchargeRequested":
            self = .surchargeRequested
        default:
            return nil
        }
    }
}
