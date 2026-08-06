//
//  SafManager.swift
//  ios-device-lib
//

import Foundation

protocol SaFManager {
    var delegate: SaFDelegate? { get set }
    func store<T: Transaction>(transaction: T, delegate: SaFDelegate)
    func listStoredTransaction() -> [Transaction]
    func removeTransaction(transaction: ProcessSaF, delegate: SaFDelegate)
}
