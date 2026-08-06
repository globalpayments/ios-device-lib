//
//  GatewayDelegate.swift
//  ios-device-lib
//

import Foundation

protocol GatewayDelegate: AnyObject {
    
    func onResponse<T: TransactionResponse>(response: T)
    func onError(error: GatewayError) // This is in use for Propay Gateway
    func onError(error: GatewayError, response: TransactionResponse?) // This is in use for Portico Gateway

    /// This method is called when a Non-Emv transaction receives TimeOut from Gateway.
    /// - Parameter response: Transaction Response
    func onTimeOutOfNonEmvTransaction()

    // Below methods used in Propay Implementation
    func requestPostalCode(maskedPan: String,
                           expiryDate:String,
                           cardholderName: String?)
    func onSuccess()
}

extension GatewayDelegate {
    func onTimeOutOfNonEmvTransaction() {}
    func onSuccess() {}
    func onError(error: GatewayError, response: TransactionResponse?) {}
}

