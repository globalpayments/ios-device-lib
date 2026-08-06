//
//  DefaultSaFManager.swift
//  ios-device-lib
//

import Foundation

class DefaultSaFManager: SaFManager {
    
    var delegate: SaFDelegate?
    var timer: Timer?
    
    init() {
        createTimer()
    }
    
    func store<T: Transaction>(transaction: T, delegate: SaFDelegate) {
        var transactionsList = [ProcessSaF]()
        var processSaf: ProcessSaF?
        
        if SafFileManager.fileExists() {
            do {
                if let transactions  = try SafFileManager.retrieve(type: [ProcessSaF].self) {
                    transactionsList = transactions
                }
            } catch {
                delegate.onError(error: SaFError.ioFailed)
            }
        }
        
        processSaf = ProcessSaF(transaction: transaction)
                
        if let processSafTransaction = processSaf {
            do {
                transactionsList.append(processSafTransaction)
                
                try SafFileManager.store(transactionsList)
                
                delegate.onTransactionStored(response: onResponse(transaction: processSafTransaction))
            } catch {
                delegate.onError(error: SaFError.ioFailed)
            }
        } else {
            delegate.onError(error: SaFError.invalidTransactionType)
            return
        }
    }
    
    func removeTransaction(transaction: ProcessSaF, delegate: SaFDelegate) {
        if let storedTransactions = listStoredTransaction() as? [ProcessSaF] {
            let updatedStoredTransactions = storedTransactions.filter { $0.clientTransactionId != transaction.clientTransactionId }
            try? SafFileManager.store(updatedStoredTransactions)
        }
        
        delegate.onTransactionRemoved()
    }
    
    func listStoredTransaction() -> [Transaction] {
        var storedTransactions = [Transaction]()
        if let sale = try? SafFileManager.retrieve(type: [ProcessSaF].self) {
            storedTransactions = sale
        }
        
        return storedTransactions
    }
      
    private func createTimer() {
        if timer == nil {
            let timer = Timer(timeInterval: 300.0,
                              target: self,
                              selector: #selector(deleteExpiredTransactions),
                              userInfo: nil,
                              repeats: true)
            
            RunLoop.current.add(timer, forMode: .common)

            self.timer = timer
        }
    }
    
    @objc private func deleteExpiredTransactions() {
        var deletedTransactions = [ProcessSaF]()

        if let storedTransactions = listStoredTransaction() as? [ProcessSaF] {
            let updatedStoredTransactions = storedTransactions.filter {
                if isTransacationExpired(transactionDate: $0.transactionDate) {
                    deletedTransactions.append($0)
                    
                    return false
                } else {
                    return true
                }
            }
            
            try? SafFileManager.store(updatedStoredTransactions)
        }
        
        delegate?.onDeletedExpiredTransactions(deletedTransactions: deletedTransactions)
    }
    
    private func isTransacationExpired(transactionDate: Date?) -> Bool {
        let transactionValidity = +30 // in days
        let currentDate = Date()
        
        if let transactionDate = transactionDate,
           let expirationDate = Calendar.current.date(byAdding: .day,
                                                      value: transactionValidity,
                                                      to: transactionDate), currentDate > expirationDate {
            return true
        } else {
            return false
        }
    }
    
    private func onResponse(transaction: ProcessSaF) -> ProcessSaFResponse {
        var total: UInt?
        var tax: UInt?
        var invoiceNumber: String?
        var cardholderName: String?
        var maskedPAN: String?
        var cardDataSourceType: EntryMode?
        var cardType: CardType?
        var transactionType: TransactionType?
        
        switch transaction.transaction {
        case let transaction as SaleTransaction:
            total = transaction.total
            tax = transaction.tax
            invoiceNumber = transaction.invoiceNumber
            cardDataSourceType = transaction.cardData?.cardEntryMode
            cardType = CreditCardHelper().getCardTypeFromRedactedPan(cardNumber: transaction.cardData?.maskedPan ?? "")
            cardholderName = transaction.cardData?.cardholderName
            maskedPAN = transaction.cardData?.maskedPan
            transactionType = .Sale

        case let transaction as AuthTransaction:
            total = transaction.total
            tax = transaction.tax
            invoiceNumber = transaction.invoiceNumber
            cardDataSourceType = transaction.cardData?.cardEntryMode
            cardType = CreditCardHelper().getCardTypeFromRedactedPan(cardNumber: transaction.cardData?.maskedPan ?? "")
            cardholderName = transaction.cardData?.cardholderName
            maskedPAN = transaction.cardData?.maskedPan
            transactionType = .Auth

        case let transaction as ReturnTransaction:
            total = transaction.total
            tax = transaction.tax
            invoiceNumber = transaction.invoiceNumber
            cardDataSourceType = transaction.cardData?.cardEntryMode
            cardType = CreditCardHelper().getCardTypeFromRedactedPan(cardNumber: transaction.cardData?.maskedPan ?? "")
            cardholderName = transaction.cardData?.cardholderName
            maskedPAN = transaction.cardData?.maskedPan
            transactionType = .Return

        case let transaction as VerifyTransaction:
            total = transaction.total
            invoiceNumber = transaction.invoiceNumber
            cardDataSourceType = transaction.cardData?.cardEntryMode
            cardType = CreditCardHelper().getCardTypeFromRedactedPan(cardNumber: transaction.cardData?.maskedPan ?? "")
            cardholderName = transaction.cardData?.cardholderName
            maskedPAN = transaction.cardData?.maskedPan
            transactionType = .Verify

        case let transaction as TokenizationTransaction:
            total = transaction.total
            invoiceNumber = transaction.invoiceNumber
            cardDataSourceType = transaction.cardData?.cardEntryMode
            cardType = CreditCardHelper().getCardTypeFromRedactedPan(cardNumber: transaction.cardData?.maskedPan ?? "")
            cardholderName = transaction.cardData?.cardholderName
            maskedPAN = transaction.cardData?.maskedPan
            transactionType = .Tokenize

        default:
            break
        }
        
        return ProcessSaFResponse(hostProcessingResult: nil,
                                  total: total,
                                  tax: tax,
                                  cardDataSourceType: cardDataSourceType,
                                  cardType: cardType,
                                  maskedPan: maskedPAN,
                                  aid: nil,
                                  applicationLabel: nil,
                                  cvm: nil,
                                  tsi: nil,
                                  tvr: nil,
                                  transactionId: transaction.clientTransactionId,
                                  transactionResult: .offlineApproved,
                                  gatewayTransactionId: nil,
                                  gatewayResponseText: nil,
                                  approvedAmount: nil,
                                  cardholderName: cardholderName,
                                  manualSignature: true,
                                  invoiceNumber: invoiceNumber,
                                  transactionType: transactionType,
                                  transactionDate: transaction.transactionDate)
    }
}
