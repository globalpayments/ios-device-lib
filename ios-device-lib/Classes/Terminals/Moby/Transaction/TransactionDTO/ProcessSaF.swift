//
//  ProcessSaF.swift
//  ios-device-lib
//

import Foundation

/// ProcessSaF Model, all amounts should be passed in Pennies format (no dollar amounts).
/// Not supported for Portico at present.
public struct ProcessSaF: Transaction {
    
    public let transaction: Transaction
    public var clientTransactionId: String
    public var invoiceNumber: String?
    public var posReferenceNumber: String?
    public var operatingUserId: String?
    public internal(set) var transactionDate: Date?
    public var isSurchargeEnabled: Bool?
    public var surchargeAmtInfo: String?
    
    enum CodingKeys: String, CodingKey {
        case sale,
        returns,
        verify,
        tokenize,
        auth,
        transactionDate
    }

    init(transaction: Transaction) {
        if (transaction as? ProcessSaF) != nil {
            fatalError("invalid argument to Transaction")
        }
        
        self.transaction = transaction
        clientTransactionId = transaction.clientTransactionId
        invoiceNumber = transaction.invoiceNumber
        posReferenceNumber = transaction.posReferenceNumber
        operatingUserId = transaction.operatingUserId
        transactionDate = Date()
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.transactionDate = try container.decodeIfPresent(Date.self, forKey: .transactionDate)

        if let value = try container.decodeIfPresent(SaleTransaction.self, forKey: .sale) {
            self.transaction = value
            self.clientTransactionId = transaction.clientTransactionId
            self.invoiceNumber = transaction.invoiceNumber
            self.posReferenceNumber = transaction.posReferenceNumber
            self.operatingUserId = transaction.operatingUserId
        } else if let value = try container.decodeIfPresent(ReturnTransaction.self, forKey: .returns) {
            self.transaction = value
            self.clientTransactionId = transaction.clientTransactionId
            self.invoiceNumber = transaction.invoiceNumber
            self.posReferenceNumber = transaction.posReferenceNumber
            self.operatingUserId = transaction.operatingUserId
        } else if let value = try container.decodeIfPresent(AuthTransaction.self, forKey: .auth) {
            self.transaction = value
            self.clientTransactionId = transaction.clientTransactionId
            self.invoiceNumber = transaction.invoiceNumber
            self.posReferenceNumber = transaction.posReferenceNumber
            self.operatingUserId = transaction.operatingUserId
        } else if let value = try container.decodeIfPresent(VerifyTransaction.self, forKey: .verify) {
            self.transaction = value
            self.clientTransactionId = transaction.clientTransactionId
            self.invoiceNumber = transaction.invoiceNumber
            self.posReferenceNumber = transaction.posReferenceNumber
            self.operatingUserId = transaction.operatingUserId
        } else if let value = try container.decodeIfPresent(TokenizationTransaction.self, forKey: .tokenize) {
            self.transaction = value
            self.clientTransactionId = transaction.clientTransactionId
            self.invoiceNumber = transaction.invoiceNumber
            self.posReferenceNumber = transaction.posReferenceNumber
            self.operatingUserId = transaction.operatingUserId
        } else {
            throw TransactionError.decodeFailed(debugMessage: "Transaction mis-match")
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(transactionDate, forKey: .transactionDate)
        
        switch transaction {
        case let value as SaleTransaction:
            try container.encode(value, forKey: .sale)
        case let value as AuthTransaction:
            try container.encode(value, forKey: .auth)
        case let value as ReturnTransaction:
            try container.encode(value, forKey: .returns)
        case let value as TokenizationTransaction:
            try container.encode(value, forKey: .tokenize)
        case let value as VerifyTransaction:
            try container.encode(value, forKey: .verify)
        default:
            throw TransactionError.decodeFailed(debugMessage: "Transaction mis-match")
        }
    }
    
    public enum TransactionError: Error {
        case decodeFailed(debugMessage: String),
        encodeFailed(debugMessage: String)
    }
}
