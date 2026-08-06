//
//  TransactionType.swift
//  ios-device-lib
//

import Foundation

public enum TransactionType: String, CaseIterable, Equatable, Codable {
    case Sale, Auth, Capture, Void, Return, Verify, Tokenize, BatchClose, TipAdjust, Reversal, ListSaf

    //ToDo:
    //Transaction type return classes migration will be part of the upcoming story
    public var transactionType: Transaction.Type {
        switch self {
        case .Sale: return SaleTransaction.self
        case .Auth: return AuthTransaction.self
        case .Capture: return CaptureTransaction.self
        case .Void: return VoidTransaction.self
        case .Return: return ReturnTransaction.self
        case .Verify: return VerifyTransaction.self
        case .Tokenize: return TokenizationTransaction.self
        case .BatchClose: return BatchCloseTransaction.self
        case .TipAdjust: return TipAdjustTransaction.self
        case .Reversal: return ReversalTransaction.self
        case .ListSaf: return ListSaF.self
        }
    }
}
