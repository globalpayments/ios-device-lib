//
//  TransactionDelegate.swift
//  ios-device-lib
//

import Foundation

public protocol TransactionDelegate: AnyObject {
    func onState(state: TransactionState)
    func requestAIDSelection(aids: [AID])
    func requestAmountConfirmation(amount: Decimal?)
    func requestSaFApproval()
    func requestPostalCode(maskedPan: String,
                           expiryDate: String,
                           cardholderName: String?)
    func onTransactionComplete(result: TransactionResult, response: TransactionResponse?)
    func onListSaFComplete(transactions: [Transaction])
    func onDeletedTransactionsComplete(deletedTransactions: [ProcessSaF])
    func onTransactionCancelled()
    func onError(error: TransactionError)
    func onTransactionWaitingForSurchargeConfirmation(result: TransactionResult, response: TransactionResponse?)
}

public extension TransactionDelegate {
    func onListSaFComplete(transactions: [Transaction]) {}
    func onDeletedTransactionsComplete(deletedTransactions: [ProcessSaF]) {}
}
