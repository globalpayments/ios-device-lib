//
//  PorticoGateway.swift
//  ios-device-lib
//

import os
import Foundation
import GlobalPaymentsApi

struct PorticoGateway: Gateway {

    // MARK: Constants
    private let TransactionStatusActive = "A"
    private let TransactionStatusCleared = "C"
    private let TransactionStatusReversed = "R"
    private let TransactionStatusVoided = "V"
    private let TransactionTypeCapture = "CreditAddToBatch"
    private let TransactionApproved = "Success"
    private let GatewayTimeOutResponseCode = "91"

    // MARK: Gateway Protocol
    var delegate: GatewayDelegate?
    var gatewayConfig: GatewayConfig

    init?<G:GatewayConfig>(config: G) {
        if #available(iOS 12.0, *) {
            os_log(.debug, "[Portico]: Config Initial Request 🚀")
        } else {
            os_log("[Portico]: Config Initial Request 🚀")
        }

        guard let porticoConfig = config as? PorticoConfig else {
            return nil
        }
        gatewayConfig = config

        GPServicesContainer.configure(porticoConfig.serviceConfig)
    }

    /// SaleTransaction Request
    /// - Parameter transaction: SaleTransaction Object
    func sale(transaction: SaleTransaction) {
        
        if #available(iOS 12.0, *) {
            os_log(.debug, "[Portico]: SaleTransaction Requested 🚀")
        } else {
            os_log("[Portico]: SaleTransaction Requested 🚀")
        }

        guard let cardData = transaction.cardData else {
            delegate?.onError(error: .badRequest(message: "Sale - Invalid CardData or Card data missing"),
                              response: nil)
            return
        }

        // Get GPCredit object from SaleTransaction
        let creditData = transaction.buildGPCredit(cardData)
        
        if let encryptionData = creditData.encryptionData,
            encryptionData.trackNumber == nil,
            cardData.maskedPAN == nil {
            delegate?.onError(error: .trackReadFail, response: nil)
            return
        }
        
        // Get GPAuthorizationBuilder object from GPCredit
        guard let builder = creditData.charge() else {
            delegate?.onError(error: .badRequest(message: "Failed to Parse Request"),
                              response: nil)

            return
        }

        builder.allowDuplicates = transaction.allowDuplicates ?? false
        builder.clientTransactionId = transaction.clientTransactionId
        builder.requestMultiUseToken = transaction.requestMultiUseToken
        builder.allowPartialAuth = transaction.allowPartialAuth ?? false
        builder.cpcReq = transaction.cpcReq ?? false
        
        if let autoSubstantiationWrapper = transaction.autoSubstantiation {
            let autoSubstantiation = GlobalPaymentsApi.AutoSubstantiation()
            autoSubstantiation.amounts = NSMutableDictionary(dictionary: autoSubstantiationWrapper.amounts)
            autoSubstantiation.realTimeSubstantiation = autoSubstantiationWrapper.realTimeSubstantiation as NSNumber?
            autoSubstantiation.merchantVerificationValue = autoSubstantiationWrapper.merchantVerificationValue as NSString?
            builder.autoSubstantiation = autoSubstantiation
        }
        
        if transaction.surchargeAmtInfo != nil {
            builder.surchargeAmount = transaction.surchargeAmtInfo
        }
        
        builder.updateBuilder(transaction)
        
        // Send Request
        builder.execute({ (response, error) in
            
            var saleResponse = transaction.buildSaleResponse(response,
                                                             surchargeFee: transaction.surchargeFee)
            
            // ADDING A MESSAGE TO GATEWAY RESPONSE TEXT WHEN SURCHARGE API IS FACING TIMEOUT ERROR
            saleResponse.surchargeRequested = transaction.surchargeRequested
            
            if error != nil {
                self.handleHostError(error,
                                     response: saleResponse)

                return
            }
            
            if let authorizedAmount = response?.authorizedAmount, !authorizedAmount.isEmpty {
                
                let surchargeFee: Double = NSDecimalNumber(decimal: transaction.surchargeFee ?? SurchargeUtility.surchargeFee.amountInDecimal).doubleValue
                
                let surchargeAmtInfoNew = (transaction.isSurchargeEnabled ?? false) ? getSurchargeAmount(authorizedAmount, surchargeFee) : "0.00"
                let newApprovedAmt = (transaction.isSurchargeEnabled ?? false) ? getNewApprovedAmount(authorizedAmount, surchargeAmtInfoNew) : authorizedAmount
                
                guard let editBulder = creditData.edit() else {
                    delegate?.onError(error: .badRequest(message: "Failed to Parse EDIT Request"),
                                      response: nil)

                    return
                }
                editBulder.gatewayTransactionId = saleResponse.gatewayTransactionId
                editBulder.clientTransactionId = transaction.clientTransactionId
                editBulder.surchargeAmtInfo = surchargeAmtInfoNew
                
                // Edit Build Sale Request
                editBulder.execute { (gpTranResponse, error) in
                    let saleGPResponse = transaction.buildSaleResponse(gpTranResponse,
                                                                       surchargeFee: transaction.surchargeFee)
                    
                    if error != nil {
                        self.handleHostError(error,
                                             response: saleGPResponse)

                        return
                    }
                    
                    if let hostResponse = response {
                        if let responseCode = hostResponse.responseCode,
                            responseCode == self.GatewayTimeOutResponseCode {
                            // Gateway Timeouts(91) should be Perform Reversals in SDK
                            self.handleGatewayTimeouts(cardData.cardEntryMode, response: saleResponse)

                            return
                        }

                        if #available(iOS 12.0, *) {
                            os_log(.debug, "[Portico]: Successful Sale Response 🔥🟢")
                        } else {
                            os_log("[Portico]: Successful Sale Response 🔥🟢")
                        }
                        
                        saleResponse.surchargeAmount = surchargeAmtInfoNew
                        saleResponse.approvedAmount = newApprovedAmt?.amountInPennies
                        
                        if let cardData = transaction.cardData {
                            saleResponse.cardholderName = TLVUtility.hexToAscii(cardData.cardData.cardholderName)
                        }
                        
                        self.delegate?.onResponse(response: saleResponse)
                    } else {
                        self.fetchTransactionSummary(transaction.clientTransactionId,
                                                     transaction: transaction)
                    }
                    
                }
            } else {
               
                var saleResponse = transaction.buildSaleResponse(response,
                                                                 surchargeFee: transaction.surchargeFee)
                
                // ADDING A MESSAGE TO GATEWAY RESPONSE TEXT WHEN SURCHARGE API IS FACING TIMEOUT ERROR
                saleResponse.surchargeRequested = transaction.surchargeRequested
                
                if let hostResponse = response {
                    if let responseCode = hostResponse.responseCode,
                        responseCode == self.GatewayTimeOutResponseCode {
                        // Gateway Timeouts(91) should be Perform Reversals in SDK
                        self.handleGatewayTimeouts(cardData.cardEntryMode, response: saleResponse)

                        return
                    }

                    if #available(iOS 12.0, *) {
                        os_log(.debug, "[Portico]: Successful Sale Response 🔥🟢")
                    } else {
                        os_log("[Portico]: Successful Sale Response 🔥🟢")
                    }
                    
                    if let cardData = transaction.cardData {
                        saleResponse.cardholderName = TLVUtility.hexToAscii( cardData.cardData.cardholderName)
                    }
                    
                    self.delegate?.onResponse(response: saleResponse)
                } else {
                    self.fetchTransactionSummary(transaction.clientTransactionId,
                                                 transaction: transaction)
                }
            }

        })
    }

    /// AuthTransaction Request
    /// - Parameter transaction: AuthTransaction object
    func auth(transaction: AuthTransaction) {
        if #available(iOS 12.0, *) {
            os_log(.debug, "[Portico]: Auth Transaction Requested 🚀")
        } else {
            os_log("[Portico]: Auth Transaction Requested 🚀")
        }

        guard let cardData = transaction.cardData else {
            delegate?.onError(error: .badRequest(message: "Auth - Invalid CardData or Card data missing"),
                              response: nil)

            return
        }

        // Get GPCredit object from AuthTransaction
        let creditData = transaction.buildGPCredit(cardData)

        // Get GPAuthorizationBuilder object from GPCredit
        guard let builder = creditData.authorize() else {
            delegate?.onError(error: .badRequest(message: "Failed to Parse Request"),
                              response: nil)

            return
        }

        builder.allowDuplicates = transaction.allowDuplicates ?? false
        builder.clientTransactionId = transaction.clientTransactionId
        builder.requestMultiUseToken = transaction.requestMultiUseToken
        builder.allowPartialAuth = transaction.allowPartialAuth ?? false
        builder.cpcReq = transaction.cpcReq ?? false
        
        if let autoSubstantiationWrapper = transaction.autoSubstantiation {
            let autoSubstantiation = GlobalPaymentsApi.AutoSubstantiation()
            autoSubstantiation.amounts = NSMutableDictionary(dictionary: autoSubstantiationWrapper.amounts)
            autoSubstantiation.realTimeSubstantiation = autoSubstantiationWrapper.realTimeSubstantiation as NSNumber?
            autoSubstantiation.merchantVerificationValue = autoSubstantiationWrapper.merchantVerificationValue as NSString?
            builder.autoSubstantiation = autoSubstantiation
        }
        
        if transaction.surchargeAmtInfo != nil {
            builder.surchargeAmount = transaction.surchargeAmtInfo
        }
        
        builder.updateBuilder(transaction)
        
        // Send Request
        builder.execute({ (response, error) in
            var authResponse = transaction.buildAuthResponse(response,
                                                             surchargeFee: transaction.surchargeFee)
            
            // ADDING A MESSAGE TO GATEWAY RESPONSE TEXT WHEN SURCHARGE API IS FACING TIMEOUT ERROR
            authResponse.surchargeRequested = transaction.surchargeRequested
            
            
            if let authorizedAmount = response?.authorizedAmount, !authorizedAmount.isEmpty {
                let surchargeFee: Double = NSDecimalNumber(decimal: transaction.surchargeFee ?? SurchargeUtility.surchargeFee.amountInDecimal).doubleValue
                
                let surchargeAmtInfoNew = (transaction.isSurchargeEnabled ?? false) ?  getSurchargeAmount(authorizedAmount, surchargeFee) : "0.00"
                
                let newApprovedAmt = getNewApprovedAmount(authorizedAmount, surchargeAmtInfoNew)
                
                guard let editBulder = creditData.edit() else {
                    delegate?.onError(error: .badRequest(message: "Failed to Parse EDIT Request"),
                                      response: nil)

                    return
                }
                editBulder.gatewayTransactionId = authResponse.gatewayTransactionId
                editBulder.clientTransactionId = transaction.clientTransactionId
                editBulder.surchargeAmtInfo = surchargeAmtInfoNew
                
                // Edit Build Sale Request
                editBulder.execute { (gpTranResponse, error) in
                    let saleGPResponse = transaction.buildAuthResponse(gpTranResponse,
                                                                       surchargeFee: Decimal(surchargeFee))
                    
                    if error != nil {
                        self.handleHostError(error,
                                             response: saleGPResponse)

                        return
                    }
                    
                    if let hostResponse = response {
                        if let responseCode = hostResponse.responseCode,
                            responseCode == self.GatewayTimeOutResponseCode {
                            // Gateway Timeouts(91) should be Perform Reversals in SDK
                            self.handleGatewayTimeouts(cardData.cardEntryMode, response: authResponse)

                            return
                        }

                        if #available(iOS 12.0, *) {
                            os_log(.debug, "[Portico]: Successful Sale Response 🔥🟢")
                        } else {
                            os_log("[Portico]: Successful Sale Response 🔥🟢")
                        }
                        
                        authResponse.surchargeAmount = surchargeAmtInfoNew
                        authResponse.approvedAmount = newApprovedAmt?.amountInPennies
                        
                        if let cardData = transaction.cardData {
                            authResponse.cardholderName = cardData.cardholderName
                            
                        }
                        
                        self.delegate?.onResponse(response: authResponse)
                    } else {
                        self.fetchTransactionSummary(transaction.clientTransactionId,
                                                     transaction: transaction)
                    }
                    
                }
            } else {
                
                if error != nil {
                    self.handleHostError(error,
                                         response: authResponse)
    
                    return
                }
    
                if let hostResponse = response {
                    if let responseCode = hostResponse.responseCode,
                        responseCode == self.GatewayTimeOutResponseCode {
                        // Gateway Timeouts(91) should be Perform Reversals in SDK
                        self.handleGatewayTimeouts(cardData.cardEntryMode, response: authResponse)
    
                        return
                    }
    
                    if #available(iOS 12.0, *) {
                        os_log(.debug, "[Portico]: Successful Auth Response 🔥🟢")
                    } else {
                        os_log("[Portico]: Successful Auth Response 🔥🟢")
                    }
                    
//                    print("IS AUTH SURCHARGE TIMEOUT \(transaction.surchargeRequested)")
                    // ADDING A MESSAGE TO GATEWAY RESPONSE TEXT WHEN SURCHARGE API IS FACING TIMEOUT ERROR
                    authResponse.surchargeRequested = transaction.surchargeRequested
                    
                    if let cardData = transaction.cardData {
                        authResponse.cardholderName = cardData.cardholderName
                        
                    }
    
                    self.delegate?.onResponse(response: authResponse)
                } else {
                    self.fetchTransactionSummary(transaction.clientTransactionId,
                                                 transaction: transaction)
                }
            }
        })
    }

    /// ReturnTransaction Request
    /// - Parameter transaction: ReturnTransaction object
    func `return`(transaction: ReturnTransaction) {
        // If cardData is not present then perform the Return with GatewayReference
        guard let cardData = transaction.cardData else {
            getTransactionStatusAndPerformAction(transaction)

            return
        }

        if #available(iOS 12.0, *) {
            os_log(.debug, "[Portico]: ReturnTransaction with cardData Requested 🚀")
        } else {
            os_log("[Portico]: ReturnTransaction with cardData Requested 🚀")
        }

        // Get GPCredit object from ReturnTransaction
        let creditData = transaction.buildGPCredit(cardData)

        // Get GPAuthorizationBuilder object from GPCredit
        guard let builder = creditData.refund() else {
            delegate?.onError(error: .badRequest(message: "Failed to Parse Request"),
                              response: nil)

            return
        }

        builder.clientTransactionId = transaction.clientTransactionId
        builder.updateBuilder(transaction)
        builder.allowPartialAuth = transaction.allowPartialAuth ?? false
        builder.gratuity = nil

        // Send Request
        builder.execute({ (response, error) in
            let returnResponse = transaction.buildReturnResponse(response)

            if error != nil {
                self.handleHostError(error,
                                     response: returnResponse)

                return
            }

            if let hostResponse = response {
                if let responseCode = hostResponse.responseCode,
                    responseCode == self.GatewayTimeOutResponseCode {
                    // Gateway Timeouts(91) should be Perform Reversals in SDK
                    self.handleGatewayTimeouts(cardData.cardEntryMode, response: returnResponse)

                    return
                }

                self.delegate?.onResponse(response: returnResponse)
            } else {
                self.fetchTransactionSummary(transaction.clientTransactionId,
                                             transaction: transaction)
            }
        })
    }

    func capture(transaction: CaptureTransaction) {
        if #available(iOS 12.0, *) {
            os_log(.debug, "[Portico]: CaptureTransaction Requested 🚀")
        } else {
            os_log("[Portico]: CaptureTransaction Requested 🚀")
        }

        // Convert CaptureTransaction into GPTransaction
        guard let gpTransaction = GPTransaction(fromId: transaction.gatewayTransactionId) else {
            delegate?.onError(error: .badRequest(message: "Missing Gateway TransactionId"),
                              response: nil)

            return
        }

        // Get GPManagementBuilder object from GPTransaction
        let builder = gpTransaction.capture()
        builder?.amount = transaction.total?.amountInDollarString
        builder?.gratuity = transaction.tip != nil ? transaction.tip!.amountInDollarString : "0"
        builder?.currency = "\(gatewayConfig.currencyCode.stringDescription)"

        // Send Request
        builder?.execute({ (hostTransaction, error) in
            let captureResponse = transaction.buildCaptureResponse(hostTransaction)

            if let response = hostTransaction {
                if isGatewayApprovedFromResponseMessage(response.responseMessage) {
                    self.delegate?.onResponse(response: captureResponse)
                } else {
                    self.delegate?.onError(error: .transactionFailed(message: response.responseMessage),
                                           response: captureResponse)
                }
            } else {
                if error != nil {
                    self.handleHostError(error,
                                         response: captureResponse)
                } else {
                    self.delegate?.onError(error: .transactionFailed(message:
                                                                        "Capture Transaction failed with unknown error"),
                                           response: captureResponse)
                }
            }
        })
    }

    func tipAdjust(transaction: TipAdjustTransaction) {
        if #available(iOS 12.0, *) {
            os_log(.debug, "[Portico]: TipAdjustTransaction Requested 🚀")
        } else {
            os_log("[Portico]: TipAdjustTransaction Requested 🚀")
        }

        // Convert TipAdjustTransaction into GPTransaction
        guard let gpTransaction = GPTransaction(fromId: transaction.gatewayTransactionId) else {
            delegate?.onError(error: .badRequest(message: "Missing Gateway TransactionId"),
                              response: nil)

            return
        }

        // Get GPManagementBuilder object from GPTransaction
        let builder = gpTransaction.edit()
        builder?.amount = transaction.total?.amountInDollarString
        builder?.gratuity = transaction.tip != nil ? transaction.tip!.amountInDollarString : "0"
        builder?.currency = "\(gatewayConfig.currencyCode.stringDescription)"

        // Send Request
        builder?.execute({ (hostTransaction, error) in
            let tipAdjustResponse = transaction.buildTipAdjustResponse(hostTransaction)

            if let response = hostTransaction {
                if isGatewayApprovedFromResponseMessage(response.responseMessage) {
                    self.delegate?.onResponse(response: tipAdjustResponse)
                } else {
                    self.delegate?.onError(error: .transactionFailed(message: response.responseMessage),
                                           response: tipAdjustResponse)
                }
            } else {
                if error != nil {
                    self.handleHostError(error,
                                         response: tipAdjustResponse)
                } else {
                    self.delegate?.onError(error: .transactionFailed(message:
                                                                        "Tip Adjust Transaction failed with unknown error"),
                                           response: tipAdjustResponse)
                }
            }
        })
    }

    func void(transaction: VoidTransaction) {
        if #available(iOS 12.0, *) {
            os_log(.debug, "[Portico]: Void Transaction Requested 🚀")
        } else {
            os_log("[Portico]: Void Transaction Requested 🚀")
        }

        getTransactionStatusAndPerformAction(transaction)
    }

    func reverse(transaction: ReversalTransaction) {
        guard let transactionId = transaction.gatewayTransactionId,
              !transactionId.isEmpty else {
            if #available(iOS 12.0, *) {
                os_log(.debug, "[Portico]: Reversal requested with Client TransactionId 🚀")
            } else {
                os_log("[Portico]: Reversal requested with Client TransactionId 🚀")
            }

            reversalWithClientTransactionId(transaction)
            return
        }

        if #available(iOS 12.0, *) {
            os_log(.debug, "[Portico]: Reversal requested with Gateway TransactionId 🚀")
        } else {
            os_log("[Portico]: Reversal requested with Gateway TransactionId 🚀")
        }

        getTransactionStatusAndPerformAction(transaction)
    }

    func batchClose(transaction: BatchCloseTransaction) {
        if #available(iOS 12.0, *) {
            os_log(.debug, "[Portico]: Batch Close Transaction 🚀")
        } else {
            os_log("[Portico]: Batch Close Transaction 🚀")
        }

        GPBatchService.closeBatch({ (hostTransaction, error) in
            var batchCloseResponse = BatchCloseResponse(transaction.clientTransactionId)
            batchCloseResponse.posReferenceId = transaction.posReferenceNumber
            batchCloseResponse.operatingUserId = transaction.operatingUserId
            batchCloseResponse.clientTxnID = transaction.clientTransactionId
            
            if let response = hostTransaction {
                if isGatewayApprovedFromResponseMessage(response.responseMessage) {
                    batchCloseResponse.isApproved = true
                    batchCloseResponse.gatewayResponseText = response.responseMessage
                    self.delegate?.onResponse(response: batchCloseResponse)
                } else {
                    self.delegate?.onError(error: .transactionFailed(message: response.responseMessage),
                                           response: batchCloseResponse)
                }
            } else {
                if error != nil {
                    self.handleHostError(error,
                                         response: batchCloseResponse)
                } else {
                    self.delegate?.onError(error: .transactionFailed(message:
                                                                        "Batch Close failed with unknown error"),
                                           response: batchCloseResponse)
                }
            }
        })
    }

    func tokenize(transaction: TokenizationTransaction) {
        if #available(iOS 12.0, *) {
            os_log(.debug, "[Portico]: TokenizeTransaction Requested 🚀")
        } else {
            os_log("[Portico]: TokenizeTransaction Requested 🚀")
        }

        guard let cardData = transaction.cardData else {
            delegate?.onError(error: .badRequest(message: "Invalid CardData or Card data missing"),
                              response: nil)

            return
        }

        // Get GPCredit object from TokenizeTransaction
        let creditData = transaction.buildGPCredit(cardData)

        // Get GPAuthorizationBuilder object from GPCredit
        guard let builder = creditData.verify() else {
            delegate?.onError(error: .badRequest(message: "Failed to Parse Request"),
                              response: nil)

            return
        }

        builder.clientTransactionId = transaction.clientTransactionId
        builder.amount = "0"
        builder.requestMultiUseToken = true
        builder.updateBuilderForVerify(transaction)

        // Send Request
        builder.execute({ (response, error) in
            let tokenizationResponse = transaction.buildTokenizedResponse(response)

            if error != nil {
                // Tokenization Requests don't need to perform the reversals
                // Portico always returns same token for a card.
                self.handleHostError(error,
                                     response: tokenizationResponse)
            }

            if let hostResponse = response {
                if let responseCode = hostResponse.responseCode,
                   responseCode == self.GatewayTimeOutResponseCode {
                    self.delegate?.onError(error: .hostTimeout,
                                           response: tokenizationResponse)

                    return
                }

                if let _ = hostResponse.token {
                    self.delegate?.onResponse(response: tokenizationResponse)
                } else {
                    self.delegate?.onError(error: .transactionFailed(message: hostResponse.responseMessage),
                                           response: tokenizationResponse)
                }
            } else {
                self.delegate?.onError(error: .transactionFailed(message: "Tokenization Failed with unknown error"),
                                       response: tokenizationResponse)
            }
        })
    }

    func verify(transaction: VerifyTransaction) {
        if #available(iOS 12.0, *) {
            os_log(.debug, "[Portico]: Verify Transaction Requested 🚀")
        } else {
            os_log("[Portico]: Verify Transaction Requested 🚀")
        }

        guard let cardData = transaction.cardData else {
            delegate?.onError(error: .badRequest(message: "Invalid CardData or Card data missing"),
                              response: nil)

            return
        }

        // Get GPCredit object from VerifyTransaction
        let creditData = transaction.buildGPCredit(cardData)

        // Get GPAuthorizationBuilder object from GPCredit
        guard let builder = creditData.verify() else {
            delegate?.onError(error: .badRequest(message: "Failed to Parse Request"),
                              response: nil)

            return
        }
        
        builder.clientTransactionId = transaction.clientTransactionId
        builder.amount = "0"
        builder.requestMultiUseToken = transaction.requestMultiUseToken
        builder.updateBuilderForVerify(transaction)
        
        // Send Request
        builder.execute({ (response, error) in
            let verifyResponse = transaction.buildVerifyResponse(response)

            if error != nil {
                self.handleHostError(error,
                                     response: verifyResponse)

                return
            }

            if let _ = response {
                self.delegate?.onResponse(response: verifyResponse)
            } else {
                self.fetchTransactionSummary(transaction.clientTransactionId,
                                             transaction: transaction)
            }
        })
    }

    // MARK: Internal
    private func handleHostError(_ error: Error?,
                                 response: TransactionResponse?) {
        guard let err = error as NSError? else {
            if #available(iOS 12.0, *) {
                os_log(.debug, "[Portico]: Received Unknown Error 🛑")
            } else {
                os_log("[Portico]: Received Unknown Error 🛑")
            }

            delegate?.onError(error: .transactionFailed(message: "Received Unknown Error"),
                              response: response)

            return
        }

        if #available(iOS 12.0, *) {
            os_log(.debug, "[Portico]: Received Host Error 🛑")
        } else {
            os_log("[Portico]: Received Host Error 🛑")
        }

        var transactionResponse = response
        transactionResponse?.transactionError = GMSError(errorDomain: err.domain,
                                                         errorCode: err.code,
                                                         localizedDescription: err.localizedDescription)

        if err.code == NSURLErrorTimedOut {
            delegate?.onError(error: .hostTimeout, response: transactionResponse)
        } else if err.code == NSURLErrorCannotConnectToHost ||
                    err.code == NSURLErrorNotConnectedToInternet {
            delegate?.onError(error: .hostNotReachable, response: transactionResponse)
        } else {
            delegate?.onError(error: .transactionFailed(message: err.localizedDescription),
                              response: transactionResponse)
        }
    }

    private func handleGatewayTimeouts(_ cardEntryMode: EntryMode, response: TransactionResponse?) {
        if #available(iOS 12.0, *) {
            os_log(.debug, "[Portico]: Host Timeout Response 🛑")
        } else {
            os_log("[Portico]: Host Timeout Response 🛑")
        }

        switch cardEntryMode {
        case .msr, .chipFallback, .manual, .token:
            self.delegate?.onTimeOutOfNonEmvTransaction()
            break

        default:
            self.delegate?.onError(error: .hostTimeout, response: response)
            break
        }
    }

    /// This function is used to fetch transaction if host provides neither error nor response
    /// - Parameter clientTransactionId: ID generated by SDK as a reference for requests that are sent to Portico
    private func fetchTransactionSummary(_ clientTransactionId: String, transaction: CardTransaction) {
        if #available(iOS 12.0, *) {
            os_log(.debug, "[Portico]: Fetch Transaction Summary Requested 🚀")
        } else {
            os_log("[Portico]: Fetch Transaction Summary Requested 🚀")
        }

        if clientTransactionId.count > 0 {
            GPReportingService.findTransactions({ (summaryResponse, hostError) in
                if let response = summaryResponse?.first {
                    switch transaction {
                    case let request as SaleTransaction:
                        let saleResponse = request.buildSaleResponse(response)
                        self.delegate?.onResponse(response: saleResponse)
                        return

                    case let request as AuthTransaction:
                        let saleResponse = request.buildAuthResponse(response)
                        self.delegate?.onResponse(response: saleResponse)
                        return

                    case let request as ReturnTransaction:
                        let saleResponse = request.buildReturnResponse(response)
                        self.delegate?.onResponse(response: saleResponse)
                        return
            
                    case let request as VerifyTransaction:
                        let verifyResponse = request.buildVerifyResponse(response)
                        self.delegate?.onResponse(response: verifyResponse)

                    default:
                        self.delegate?.onError(error: .badRequest(message: "Passed invalid request or transaction thats not supported yet"),
                                               response: nil)
                    }
                } else {
                    if hostError != nil {
                        self.handleHostError(hostError,
                                             response: nil)
                    } else {
                        self.delegate?.onError(error: .transactionFailed(message: "Reporting Service failed to fetch transaction summary"),
                                               response: nil)
                    }
                }
            }, withCriteria: ["ClientTxnId": clientTransactionId])
        }
    }

    private func reversalWithClientTransactionId(_ reversal: ReversalTransaction) {
        // Create Management Builder
        if let builder = GPTransaction(fromClientTransactionId: reversal.clientTransactionId),
           let reverse = builder.reverse()  {
            reverse.amount = reversal.total?.amountInDollarString
            reverse.gratuity = reversal.tip?.amountInDollarString
            reverse.currency = "\(gatewayConfig.currencyCode.stringDescription)"
            reverse.invoiceNumber = reversal.invoiceNumber

            if let tlv = reversal.tlv {
                // Remove portico blacklisted tags before mapping to builder
                let tlvData = TLVUtility.stripTags(emvTagDescriptors: Utilities.porticoBlackListedEmvTags(), fromEmvTags: TLVDecoder.decode(withTLVString: tlv))
                // Map TLV Data
                reverse.tagData = TLVUtility.fetchIccDataString(fromEmvTagsArray: tlvData)
            }

            // Execute
            reverse.execute({ (transaction, error) in
                let revesed = reversal.buildReversalResponse(transaction)

                if let _ = transaction {
                    self.delegate?.onResponse(response: revesed)
                } else {
                    if error != nil {
                        self.handleHostError(error,
                                             response: revesed)
                    } else {
                        self.delegate?.onError(error: .transactionFailed(message: "Reversal failed with an unknown error"),
                                               response: revesed)
                    }
                }
            })
        } else {
            delegate?.onError(error: .requestFailed(message: "Failed to build Reversal Request with Client Transaction Id"),
                              response: nil)
        }
    }

    /// Checks the status of the transaction based on the transaction id
    /// and performs one of the following actions
    /// - Parameter transaction: Transaction of type GatewayTransaction
    private func getTransactionStatusAndPerformAction(_ transaction: GatewayReferenceTransaction) {
        if #available(iOS 12.0, *) {
            os_log(.debug, "[Portico]: Get Transaction Status 🚀")
        } else {
            os_log("[Portico]: Get Transaction Status 🚀")
        }

        guard let transactionId = transaction.gatewayTransactionId,
            transactionId.count > 0 else {
                delegate?.onError(error: .badRequest(message: "Gateway TransactionId is missing or invalid"),
                                  response: nil)

                return
        }

        GPReportingService.transactionDetail(transactionId) { (transactionSummary, hostError) in
            if let summary = transactionSummary {
                if #available(iOS 12.0, *) {
                    os_log(.debug, "[Portico]: Get Transaction Status finished with Success 🔥🟢")
                } else {
                    os_log("[Portico]: Get Transaction Status finished with Success 🔥🟢")
                }

                if let serviceName = summary.serviceName,
                   serviceName.caseInsensitiveCompare(self.TransactionTypeCapture) == .orderedSame {
                    PorticoUtility.updateOriginalTransactionIdCopy(summary.originalTransactionId)

                    if PorticoUtility.isOriginalTransactionIdValid() {
                        self.getParentTransactionSummary(transaction)
                    } else {
                        // This should never occur but in case it does perform
                        // an action based on the transaction status
                        self.performActionBasedOnTransactionStatus(transaction,
                                                                   transactionSummary: summary,
                                                                   isCaptured: true)
                    }
                } else {
                    self.performActionBasedOnTransactionStatus(transaction,
                                                               transactionSummary: summary,
                                                               isCaptured: false)
                }
            } else {
                if hostError != nil {
                    self.handleHostError(hostError,
                                         response: nil)
                } else {
                    self.delegate?.onError(error: .transactionFailed(message: "Failed to get Transaction Status from host"),
                                           response: nil)
                }
            }
        }
    }

    private func getParentTransactionSummary(_ transaction: GatewayReferenceTransaction) {
        if #available(iOS 12.0, *) {
            os_log(.debug, "[Portico]: Fetch Parent Transaction Summary Requested 🚀")
        } else {
            os_log("[Portico]: Fetch Parent Transaction Summary Requested 🚀")
        }

        guard let originalTransactionId = PorticoUtility.originalTransactionIdCopy else {
            delegate?.onError(error: .badRequest(message: "Original Transaction ID is missing"),
                              response: nil)

            return
        }

        GPReportingService.transactionDetail(originalTransactionId) { (summary, error) in
            if let response = summary {
                self.performActionBasedOnTransactionStatus(transaction,
                                                           transactionSummary: response,
                                                           isCaptured: true)
            } else {
                if error != nil {
                    self.handleHostError(error,
                                         response: nil)
                } else {
                    self.delegate?.onError(error: .transactionFailed(message: "Failed to get Parent Transaction Detail"),
                                           response: nil)
                }
            }
        }
    }

    private func performActionBasedOnTransactionStatus(_ transaction: GatewayReferenceTransaction,
                                                       transactionSummary: GPTransactionSummary?,
                                                       isCaptured: Bool) {
        if #available(iOS 12.0, *) {
            os_log(.debug, "[Portico]: Performing action based on Transaction Status 🟢")
        } else {
            os_log("[Portico]: Performing action based on Transaction Status 🟢")
        }

        if let transactionStatus = transactionSummary?.status,
            transactionStatus.count > 0 {
            if transactionStatus.caseInsensitiveCompare(TransactionStatusActive) == .orderedSame {
                // Open batch
                let tip = NSDecimalNumber(string: transactionSummary?.gratuityAmount)
                let settlementAmount = NSDecimalNumber(string: transactionSummary?.settlementAmount)

                // If transaction is of Type Auth/Capture then Tip Edit requires here.
                // Tip needs to be Edited before performing any action here.
                if isCaptured && tip != .notANumber &&
                    tip.compare(NSDecimalNumber.zero) == .orderedDescending {
                    editTransaction(transaction,
                                    transactionSummary: transactionSummary)
                } else {
                    // Original authorized amount will always be greater than the partially
                    // requested reversal amount or equal to requested void amount

                    let authorizedAmount = NSDecimalNumber(string: transactionSummary?.authorizedAmount)
                    let zeroAmount = NSDecimalNumber.zero
                   
                    if settlementAmount.compare(authorizedAmount) != ComparisonResult.orderedSame,
                       settlementAmount.compare(zeroAmount) == ComparisonResult.orderedDescending,
                       transaction.transactionType == TransactionType.Return {
                        
                        performRefundByReference(transaction)
                        
                    } else if let total = transaction.total?.nsDecimalNumber,
                       total != .notANumber, authorizedAmount != .notANumber,
                       authorizedAmount.compare(total) != .orderedAscending {
                        handleReversalTransaction(transaction,
                                                  reversalAmount: nil,
                                                  transactionSummary: transactionSummary,
                                                  isTransactionEdited: false)
                    } else {
                        delegate?.onError(error: .badRequest(message: "Invalid amount requested in Transaction."),
                                          response: nil)
                    }
                }
            } else if transactionStatus.caseInsensitiveCompare(TransactionStatusCleared) == .orderedSame {
                // Perform Refund here
                performRefundByReference(transaction)
            } else {
                // Status: `R` - Reversed, `V` - Voided, this avoid host interaction if its already been voided or reversed
                if transactionStatus.caseInsensitiveCompare(TransactionStatusReversed) == .orderedSame ||
                    transactionStatus.caseInsensitiveCompare(TransactionStatusVoided) == .orderedSame {
                    delegate?.onError(error: .badRequest(message: "This Transaction was already reversed or voided."),
                                      response: nil)
                } else {
                    // Perform Void here
                    performVoid(transaction)
                }
            }
        } else if transactionSummary != nil && transactionSummary?.gatewayResponseCode != nil {
            delegate?.onError(error: .transactionFailed(message: transactionSummary?.gatewayResponseMessage ??
                                                            "Transaction Failed, Response Code: \(String(describing: transactionSummary?.gatewayResponseCode!))"),
                              response: nil)
        } else {
            delegate?.onError(error: .badRequest(message: "Error in fetching Transaction Status"),
                              response: nil)
        }
    }

    private func performRefundByReference(_ transaction: GatewayReferenceTransaction) {
        if #available(iOS 12.0, *) {
            os_log(.debug, "[Portico]: ReturnTransaction with reference Requested 🚀")
        } else {
            os_log("[Portico]: ReturnTransaction with reference Requested 🚀")
        }

        let gatewayTransactionId = PorticoUtility.isOriginalTransactionIdValid() ?
            PorticoUtility.originalTransactionIdCopy : transaction.gatewayTransactionId

        // Convert ReturnTransaction to GPTransaction
        let gpTransaction = GPTransaction(fromId: gatewayTransactionId)

        // Get GPManagementBuilder object from GPTransaction
        let builder = gpTransaction?.refund()
        builder?.amount = transaction.total?.amountInDollarString
        builder?.currency = "\(gatewayConfig.currencyCode.stringDescription)"
        builder?.invoiceNumber = transaction.invoiceNumber

        // Send Request to Gateway
        builder?.execute({ (hostResponse, error) in
            PorticoUtility.updateOriginalTransactionIdCopy(nil)

            if let response = hostResponse {
                switch transaction {
                case let transaction as ReversalTransaction:
                    let reversalResponse = transaction.buildReversalResponse(response)
                    self.delegate?.onResponse(response: reversalResponse)
                    return

                case let transaction as VoidTransaction:
                    let voidResponse = transaction.buildVoidResponse(response)
                    self.delegate?.onResponse(response: voidResponse)
                    return

                case let transaction as ReturnTransaction:
                    let returnResponse = transaction.buildReturnResponse(response)
                    self.delegate?.onResponse(response: returnResponse)
                    return

                default:
                    self.delegate?.onError(error: .badRequest(message: "Invalid Request"),
                                           response: nil)
                    return
                }
            } else {
                if error != nil {
                    self.handleHostError(error,
                                         response: nil)
                } else {
                    self.delegate?.onError(error: .transactionFailed(message: "Transaction Refund failed with an unknown error"),
                                           response: nil)
                }
            }
        })
    }

    private func performVoid(_ transaction: GatewayReferenceTransaction) {
        if #available(iOS 12.0, *) {
            os_log(.debug, "[Portico]: Performing Void 🚀")
        } else {
            os_log("[Portico]: Performing Void 🚀")
        }

        let gatewayTransactionId = PorticoUtility.isOriginalTransactionIdValid() ?
            PorticoUtility.originalTransactionIdCopy : transaction.gatewayTransactionId

        // Convert VoidTransaction to GPTransaction
        let gpTransaction = GPTransaction(fromId: gatewayTransactionId)

        // Get GPManagementBuilder object from GPTransaction
        let builder = gpTransaction?.voidTransaction()
        builder?.currency = "\(gatewayConfig.currencyCode.stringDescription)"
        builder?.invoiceNumber = transaction.invoiceNumber

        // Send Request to Gateway
        builder?.execute({ (hostResponse, error) in
            PorticoUtility.updateOriginalTransactionIdCopy(nil)

            if let response = hostResponse {
                switch transaction {
                case let transaction as ReversalTransaction:
                    let reversalResponse = transaction.buildReversalResponse(response)
                    self.delegate?.onResponse(response: reversalResponse)
                    return

                case let transaction as VoidTransaction:
                    let voidResponse = transaction.buildVoidResponse(response)
                    self.delegate?.onResponse(response: voidResponse)
                    return

                case let transaction as ReturnTransaction:
                    let returnResponse = transaction.buildReturnResponse(response)
                    self.delegate?.onResponse(response: returnResponse)
                    return

                default:
                    self.delegate?.onError(error: .badRequest(message: "Invalid Request"),
                                           response: nil)
                    return
                }
            } else {
                if error != nil {
                    self.handleHostError(error,
                                         response: nil)
                } else {
                    self.delegate?.onError(error: .transactionFailed(message: "Transaction Void failed with an unknown error"),
                                           response: nil)
                }
            }
        })
    }

    private func editTransaction(_ transaction: GatewayReferenceTransaction,
                                 transactionSummary: GPTransactionSummary?) {
        if #available(iOS 12.0, *) {
            os_log(.debug, "[Portico]: Editing Transaction Requested 🚀")
        } else {
            os_log("[Portico]: Editing Transaction Requested 🚀")
        }

        var requestReversalAmount = transaction.total?.amountInDollarString
        let settlementAmount = NSDecimalNumber(string: transactionSummary?.settlementAmount)
        let gratuityAmount = NSDecimalNumber(string: transactionSummary?.gratuityAmount)
        var settledAmountWithoutTip = NSDecimalNumber.zero

        if settlementAmount != .notANumber {
            settledAmountWithoutTip = settlementAmount

            // Subtract Gratuity from Settlement amount
            if gratuityAmount != .notANumber &&
                gratuityAmount.compare(NSDecimalNumber.zero) == .orderedDescending {
                settledAmountWithoutTip = settlementAmount.subtracting(gratuityAmount)
            }
        }

        if transaction is VoidTransaction || transaction is ReversalTransaction {
            requestReversalAmount = transactionSummary?.authorizedAmount
        } else {
            if let totalAmount = transaction.total, totalAmount > 0,
               let tipAmount = transaction.tip, tipAmount > 0 {
                let requestedReversalAmountWithoutTip = totalAmount - tipAmount

                // Partial reversal with tip included in the reversal amount
                requestReversalAmount = requestedReversalAmountWithoutTip.amountInDollarString
            }
        }

        // Convert GatewayTransaction into GPTransaction
        let gpTransaction = GPTransaction(fromId: transactionSummary?.transactionId)

        // Get GPManagementBuilder object from GPTransaction
        var builder = gpTransaction?.edit()
        builder = builder?.withGratuity("0")
        builder = builder?.withAmount(settledAmountWithoutTip.stringValue)
        builder?.currency = "\(gatewayConfig.currencyCode.stringDescription)"

        // Send Request to Gateway
        builder?.execute({ (hostResponse, hostError) in
            if let response = hostResponse {
                if response.responseMessage.caseInsensitiveCompare(self.TransactionApproved) == .orderedSame {
                    transactionSummary?.settlementAmount = settledAmountWithoutTip.stringValue

                    // Reverse the amount after negating the gratuity amount from the settlement amount
                    self.handleReversalTransaction(transaction,
                                                   reversalAmount: NSDecimalNumber(string: requestReversalAmount),
                                                   transactionSummary: transactionSummary,
                                                   isTransactionEdited: true)
                } else {
                    switch transaction {
                    case let transaction as ReversalTransaction:
                        let reversalResponse = transaction.buildReversalResponse(response)
                        self.delegate?.onResponse(response: reversalResponse)
                        return

                    case let transaction as VoidTransaction:
                        let voidResponse = transaction.buildVoidResponse(response)
                        self.delegate?.onResponse(response: voidResponse)
                        return

                    case let transaction as ReturnTransaction:
                        let returnResponse = transaction.buildReturnResponse(response)
                        self.delegate?.onResponse(response: returnResponse)
                        return
                        
                    default:
                        self.delegate?.onError(error: .badRequest(message: "Invalid Request"),
                                               response: nil)
                        return
                    }
                }
            } else {
                if hostError != nil {
                    self.handleHostError(hostError,
                                         response: nil)
                } else {
                    self.delegate?.onError(error: .transactionFailed(message: "Transaction Edit failed with unknown error"),
                                           response: nil)
                }
            }
        })
    }

    private func handleReversalTransaction(_ transaction: GatewayReferenceTransaction,
                                           reversalAmount: NSDecimalNumber?,
                                           transactionSummary: GPTransactionSummary?,
                                           isTransactionEdited: Bool) {
        if #available(iOS 12.0, *) {
            os_log(.debug, "[Portico]: handling ReversalTransaction 🚀")
        } else {
            os_log("[Portico]: handling ReversalTransaction 🚀")
        }

        let builder = buildReversalRequest(transaction,
                                           reversalAmount: reversalAmount,
                                           transactionSummary: transactionSummary)
        builder?.currency = "\(gatewayConfig.currencyCode.stringDescription)"
        builder?.invoiceNumber = transaction.invoiceNumber

        if let transaction = transaction as? ReversalTransaction, let tlv = transaction.tlv {
            // Remove portico blacklisted tags before mapping to builder
            let tlvData = TLVUtility.stripTags(emvTagDescriptors: Utilities.porticoBlackListedEmvTags(), fromEmvTags: TLVDecoder.decode(withTLVString: tlv))
            // Map TLV Data
            builder?.tagData = TLVUtility.fetchIccDataString(fromEmvTagsArray: tlvData)
        }

        // Send Request to Gateway
        builder?.execute { (hostResponse, hostError) in
            PorticoUtility.updateOriginalTransactionIdCopy(nil)

            if let response = hostResponse {
                os_log("%@", response)

                switch transaction {
                case let transaction as ReversalTransaction:
                    let reversalResponse = transaction.buildReversalResponse(response)
                    self.delegate?.onResponse(response: reversalResponse)
                    return

                case let transaction as VoidTransaction:
                    let voidResponse = transaction.buildVoidResponse(response)
                    self.delegate?.onResponse(response: voidResponse)
                    return

                case let transaction as ReturnTransaction:
                    let returnResponse = transaction.buildReturnResponse(response)
                    // Check if we should add tip back after the Returns.
                    // If required to add tip back then make another request to Portico
                    if self.shouldAddTipBack(transaction,
                                             isTransactionEdited: isTransactionEdited,
                                             response: returnResponse) {
                        self.addTipBack(transaction,
                                        summary: transactionSummary,
                                        balanceAmount: NSDecimalNumber(string: builder?.authAmount),
                                        reversalResponse: returnResponse)
                    } else {
                        self.delegate?.onResponse(response: returnResponse)
                    }
                    return

                default:
                    self.delegate?.onError(error: .badRequest(message: "Invalid Request"),
                                           response: nil)
                    return
                }
            } else {
                if hostError != nil {
                    self.handleHostError(hostError,
                                         response: nil)
                } else {
                    self.delegate?.onError(error: .transactionFailed(message: "Transaction Reversal failed with unknown error"),
                                           response: nil)
                }
            }
        }
    }

    private func buildReversalRequest(_ transaction: GatewayReferenceTransaction,
                                      reversalAmount: NSDecimalNumber?,
                                      transactionSummary: GPTransactionSummary?) -> GPManagementBuilder? {
        let total = reversalAmount != nil ? reversalAmount : transaction.total?.nsDecimalNumber ?? NSDecimalNumber.zero
        let gatewayTransactionId = PorticoUtility.isOriginalTransactionIdValid() ?
            PorticoUtility.originalTransactionIdCopy : transaction.gatewayTransactionId

        var isPartialVoid = false

        if let total = total,
           total.compare(NSDecimalNumber(string: transactionSummary?.authorizedAmount)) == .orderedAscending {
            isPartialVoid = true
        }

        var builder = GPTransaction(fromId: gatewayTransactionId).reverse()

        // For partial reversals portico requires the partial amount
        if let summary = transactionSummary, isPartialVoid {
            builder = builder?.withAmount(summary.authorizedAmount)

            let settlementAmount = NSDecimalNumber(string: summary.settlementAmount)
            let adjustedAuthAmount = settlementAmount.subtracting(total ?? .zero)

            builder = builder?.withAuthAmount(adjustedAuthAmount.stringValue)
        } else {
            // Full amount reversal
            builder?.amount = total?.stringValue
        }

        if transaction is ReversalTransaction {
            builder?.tagData = (transaction as! ReversalTransaction).tlv
        }

        return builder
    }

    /// For Portico we negate the adjusted tip before the reversal is processed, so the negated tip
    /// must be added back if the user not requested for the tip reversal or the reversal failed for
    /// some reason.
    /// - Parameters:
    ///   - transaction: Transaction Request
    ///   - isTransactionEdited: isTransactionEdited flag
    ///   - response: Transaction Response
    /// - Returns: true for partial reversals if tip is adjusted and the request does not contain the
    /// tip reversal or reversal fails and tip is adjusted.
    private func shouldAddTipBack(_ transaction: ReturnTransaction,
                                  isTransactionEdited: Bool,
                                  response: ReturnResponse) -> Bool {
        return ((transaction.tip != nil && transaction.tip == 0) && isTransactionEdited)
            || (!response.isApproved && isTransactionEdited)
    }

    /// For partial reversal of a tip adjusted transactions, if the tip amount is not included in the
    /// reversal amount, it should be added back to the balance amount.
    /// - Parameters:
    ///   - transaction: Return Transaction Request
    ///   - summary: GPTransactionSummary
    ///   - balanceAmount: Balance amount of the transaction after the partial return.
    ///   - reversalResponse: ReturnResponse
    private func addTipBack(_ transaction: ReturnTransaction,
                            summary: GPTransactionSummary?,
                            balanceAmount: NSDecimalNumber?,
                            reversalResponse: ReturnResponse) {
        if #available(iOS 12.0, *) {
            os_log(.debug, "[Portico]: Adding Tip Back 🚀")
        } else {
            os_log("[Portico]: Adding Tip Back 🚀")
        }

        let addTipErrorMessage = "Unable to edit transaction to add tip back after reversal. "
        var amountBalance = NSDecimalNumber.zero
        if balanceAmount != .notANumber &&
            NSDecimalNumber(string: summary?.gratuityAmount) != .notANumber {
            amountBalance = balanceAmount?.adding(NSDecimalNumber(string: summary?.gratuityAmount)) ?? 0
        }

        var builder = GPTransaction(fromId: summary?.transactionId)?.edit()
        builder = builder?.withAmount(amountBalance.stringValue)
        builder?.gratuity = summary?.gratuityAmount
        builder?.currency = "\(gatewayConfig.currencyCode.stringDescription)"

        // Send Request to Gateway
        builder?.execute{ (addTipResponse, hostError) in
            if let hostResponse = addTipResponse {
                var editResponse = transaction.buildReturnResponse(hostResponse)

                if editResponse.isApproved {
                    self.delegate?.onResponse(response: reversalResponse)
                } else {
                    if #available(iOS 12.0, *) {
                        os_log(.debug, "[Portico]: Could not add tip back.")
                    } else {
                        os_log("[Portico]: Could not add tip back.")
                    }

                    editResponse.gatewayResponseText = addTipErrorMessage + hostResponse.responseMessage
                    self.delegate?.onResponse(response: editResponse)
                }
            } else {
                if hostError != nil {
                    self.handleHostError(hostError,
                                         response: nil)
                } else {
                    self.delegate?.onError(error: .transactionFailed(message: addTipErrorMessage),
                                           response: nil)
                }
            }
        }
    }

    // MARK: Check Bin Card for add surcharge if needed
    func binCardCheck(transaction: CardTransaction, cardData: AnyCardData,
                      completion: @escaping ((_ response: SurchargeRequestedResponse?,
                                              _ error: Error?) -> Void)) {
        
        if #available(iOS 12.0, *) {
            os_log(.debug, "[Portico]: SaleTransaction Requested 🚀")
        } else {
            os_log("[Portico]: SaleTransaction Requested 🚀")
        }

        if cardData == nil {
            delegate?.onError(error: .badRequest(message: "binCardCheck - Invalid CardData or Card data missing"),
                              response: nil)
            return
        }

        // Get GPCredit object from SaleTransaction
        let creditData = transaction.buildGPCredit(cardData)
        
        if let encryptionData = creditData.encryptionData,
            encryptionData.trackNumber == nil,
            cardData.maskedPAN == nil {
            delegate?.onError(error: .trackReadFail, response: nil)
            return
        }
        
        // Get GPAuthorizationBuilder object from GPCredit
        guard let builder = creditData.surcharge() else {
            delegate?.onError(error: .badRequest(message: "Failed to Parse Request"),
                              response: nil)

            return
        }
        
        // Send Request
        builder.requestMultiUseToken = false;
        builder.execute({ (response, error) in
            if error != nil {
                delegate?.onError(error: .trackReadFail, response: nil)
                completion(nil, error)
                return
            }

            if let responseCode = response?.responseCode, responseCode == "20" {
                let responseMessage = response?.responseMessage ?? "Timeout"
                completion(nil, NSError(domain: responseMessage,
                                        code: Int(responseCode) ?? 20, userInfo: nil))
                return
            }
            
            var isSurchargeable: SurchargeEligibility = .U
            
            if response?.isSurchargeable == "Y" {
                isSurchargeable = .Y
            } else {
                isSurchargeable = .N
            }
            let surchargeFee = transaction.surchargeFee ?? Decimal(SurchargeUtility.surchargeFee)
            let surchargeRequest = SurchargeRequestedResponse("", transactionId: "",
                                                              surchargeRequested: isSurchargeable,
                                                              surchargeFee: "\(surchargeFee)%",
                                                              tokenizedCard: nil,
                                                              transactionResult: .surchargeRequested,
                                                              gatewayResponseText: nil, gatewayResponseCode: nil,
                                                              approvedAmount: nil, transactionDescription: "",
                                                              transactionError: nil)
            completion(surchargeRequest, nil)
        })
       
    }
    
}

extension PorticoGateway {
    func getTransactionDetail(transactionId: String, completion: @escaping ((_ response: GPTransactionSummary?,
                                                                             _ error: Error?) -> Void)) {
        
        
        GPReportingService.transactionDetail(transactionId) { (transactionSummary, hostError) in
            if let summary = transactionSummary {
                if #available(iOS 12.0, *) {
                    os_log(.debug, "[Portico]: Get Transaction Status finished with Success 🔥🟢")
                } else {
                    os_log("[Portico]: Get Transaction Status finished with Success 🔥🟢")
                }

                completion(summary, nil)
                
            }
            if let hostError {
                completion(nil, hostError)
            }
        }
    }
    
    private func getSurchargeAmount(_ total: String?, _ surchargePercent: Double) -> String? {
        guard let total = total else { return "" }
        
        let totalAmt = NSDecimalNumber(string: total).doubleValue
        let fee = surchargePercent
        
        return String(((totalAmt * fee)/100))
    }
    
    private func getNewApprovedAmount(_ total: String?, _ surchargeAmt: String?) -> String? {
        guard let total = total else { return "" }
        
        let totalAmt = NSDecimalNumber(string: total).doubleValue
        let surchargeAmt = NSDecimalNumber(string: surchargeAmt).doubleValue
        
        
        return String((totalAmt - surchargeAmt))
    }
}
