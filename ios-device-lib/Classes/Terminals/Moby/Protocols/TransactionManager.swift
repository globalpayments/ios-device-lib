//
//  TransactionManager.swift
//  ios-device-lib
//

import Foundation

protocol TransactionManager: GatewayDelegate, TerminalTransactionDelegate, SaFDelegate {
    var terminal: Terminal? { get }
    var gateway: Gateway { get }
    var delegate: TransactionDelegate? { get }
    var transaction: Transaction? { get }
    var transactionResponse: TransactionResponse? { get }
    var transactionState: TransactionState { get }
    var safManager: SaFManager { get }
    var cancelRequested: Bool { get }

    init(gateway: Gateway, terminal: Terminal?)
    func start<T: Transaction>(transaction: T, entryModes: [EntryMode], delegate: TransactionDelegate)
    func continueWithSurchargeAcceptance<T>(transaction: T, entryModes: [EntryMode], delegate: TransactionDelegate)
    func confirm(amount: Decimal)
    func approveSaF()
    func listSaF(delegate: TransactionDelegate)
    func select(aid: AID)
    func postalCode(postalCode: String)
    func cancelTransaction()
    func releaseDevice()
    func deleteSafTransaction()
}
