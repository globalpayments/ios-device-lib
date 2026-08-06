//
//  SafManagerDelegate.swift
//  ios-device-lib
//

import Foundation

public protocol SaFDelegate {
    func onTransactionStored(response: TransactionResponse)
    func onTransactionRemoved()
    func onDeletedExpiredTransactions(deletedTransactions: [ProcessSaF])
    func onError(error: SaFError)
}
