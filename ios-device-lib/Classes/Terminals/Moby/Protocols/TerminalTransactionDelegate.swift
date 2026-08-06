//
//  TerminalTransactionDelegate.swift
//  ios-device-lib
//

import Foundation

protocol TerminalTransactionDelegate {
    func onState(state: TransactionState)
    func requestAIDSelection(aids: [AID])
    func requestAmountConfirmation(amount: Decimal?)
    func requestOnlineProcessing(cardData: AnyCardData, isSurcharge: Bool)
    func requestReversal(tlv: String?)
    func onICCTransactionComplete(result: TransactionResult, tlv:String?)
    func onICCTransactionCancelled()
    func onError(terminalError: TerminalError)
    func requestOnlineBinCheck(cardData: AnyCardData, completion: @escaping ((_ response: SurchargeRequestedResponse?,
                                                       _ error: Error?) -> Void))
    func onTransactionWaitingForSurchargeConfirmation(result: TransactionResult,
                                                             response: TransactionResponse?)
    func isSurchargeEnabled() -> Bool
    func setSurchargeTimeOutError(isSurchargeTimeOutError: Bool,
                                  surchargeElibigility: SurchargeEligibility, completion: @escaping(()->Void))
}

public enum TransactionResult: UInt, Codable {
    case approved,
    partialApproval,
    terminated,
    declined,
    onlineDeclined,
    offlineApproved,
    offlineDecline,
    postAuthChipDecline,
    canceled,
    timeout, // Terminal Timeout
    capkFail,
    notIcc,
    cardBlocked,
    deviceError,
    noEmvApps,
    iccCardRemoved,
    cardSchemeNotMatched,
    success,
    reversalRequired, // This is used currently in Ingenico Terminal Implementaions only.
    fail,
    hostTimeout, // URL/Network Timeout
    networkError,
    surchargeRequested

    public typealias RawValue = String

    public var rawValue: RawValue {
        switch self {
        case .approved:
            return "approved"
        case .partialApproval:
            return "partialApproval"
        case .terminated:
            return "terminated"
        case .declined:
            return "declined"
        case .onlineDeclined:
            return "onlineDeclined"
        case .offlineApproved:
            return "offlineApproved"
        case .offlineDecline:
            return "offlineDecline"
        case .postAuthChipDecline:
            return "postAuthChipDecline"
        case .canceled:
            return "canceled"
        case .timeout:
            return "timeout"
        case .capkFail:
            return "capkFail"
        case .notIcc:
            return "notIcc"
        case .cardBlocked:
            return "cardBlocked"
        case .deviceError:
            return "deviceError"
        case .noEmvApps:
            return "noEmvApps"
        case .iccCardRemoved:
            return "iccCardRemoved"
        case .cardSchemeNotMatched:
            return "cardSchemeNotMatched"
        case .success:
            return "success"
        case .reversalRequired:
            return "reversalRequired"
        case .fail:
            return "fail"
        case .hostTimeout:
            return "hostTimeout"
        case .networkError:
            return "networkError"
        case .surchargeRequested:
            return "surchargeRequested"
        }
    }

    public init?(rawValue: String) {
        switch rawValue {
        case "approved":
            self = .approved
        case "partialApproval":
            self = .partialApproval
        case "terminated":
            self = .terminated
        case "declined":
            self = .declined
        case "onlineDeclined":
            self =  .onlineDeclined
        case "offlineApproved":
            self = .offlineApproved
        case "offlineDecline":
            self =  .offlineDecline
        case "postAuthChipDecline":
            self =  .postAuthChipDecline
        case "canceled":
            self = .canceled
        case "timeout":
            self = .timeout
        case "capkFail":
            self = .capkFail
        case "notIcc":
            self = .notIcc
        case "cardBlocked":
            self = .cardBlocked
        case "deviceError":
            self = .deviceError
        case "noEmvApps":
            self = .noEmvApps
        case "iccCardRemoved":
            self = .iccCardRemoved
        case "cardSchemeNotMatched":
            self = .cardSchemeNotMatched
        case "success":
            self = .success
        case "reversalRequired":
            self = .reversalRequired
        case "fail":
            self = .fail
        case "hostTimeout":
            self = .hostTimeout
        case "networkError":
            self = .networkError
        case "surchargeRequested":
            self = .surchargeRequested
        default:
            self = .canceled
        }
    }
    
    func reversalReason() -> ReversalReason {
        switch self {
        case .declined, .reversalRequired, .postAuthChipDecline:
            return .chipDeclined
        case .iccCardRemoved:
            return .prematureChipRemoval
        case .timeout:
            return .deviceTimeOut
        case .canceled:
            return .voidedByCustomer
        case .deviceError:
            return .deviceUnavailable
        case .surchargeRequested:
            return .surchargeRequested
        default:
            return .undefined
        }
    }
}
