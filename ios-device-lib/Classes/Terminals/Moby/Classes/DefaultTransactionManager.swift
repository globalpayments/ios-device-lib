//
//  DefaultTransactionManager.swift
//  ios-device-lib
//

import Foundation


class DefaultTransactionManager: TransactionManager {

    var terminal: Terminal?
    var gateway: Gateway
    var delegate: TransactionDelegate?
    var transaction: Transaction?
    var transactionResponse: TransactionResponse?
    var reversal: ReversalTransaction?
    var reversalResponse: ReversalResponse?
    var transactionState: TransactionState = .ready
    var transactionResult: TransactionResult?
    var safManager: SaFManager
    var cardData: CardData?
    var cancelRequested = false
    var wentOnline = false
    var receivedGatewayResponse = false
    var reversalRequested = false
    var reversalTlv: String?
    var safTransaction: ProcessSaF?
    var hostResponse: HostProcessingResult?
    var cardFlowType: BBDeviceCheckCardResult?
    var isSurchargeTimeOutError: Bool?
    var surchargeEligibility: SurchargeEligibility?
    
    private enum ApplicationCryptogramType: Int {
        case ARQC = 80
        case TC = 40
        case AAC = 0

        var description: String {
            switch self {
            case .ARQC: return "ARQC"
            case .TC: return "TC"
            case .AAC: return "AAC"
            }
        }
    }

    required init(gateway: Gateway, terminal: Terminal?) {
        self.gateway = gateway
        self.terminal = terminal
        safManager = DefaultSaFManager()
        safManager.delegate = self
        self.gateway.delegate = self
        self.terminal?.transactionDelegate = self
    }

    func start<T>(transaction: T, entryModes: [EntryMode], delegate: TransactionDelegate) where T : Transaction {
        self.delegate = delegate
        defer {
            self.delegate?.onState(state: transactionState)
        }

        guard transactionState == .ready, self.transaction == nil else {
            self.delegate?.onError(error: .transactionInProgress)
            return
        }

        if let transaction =  transaction as? ProcessSaF {
            self.safTransaction = transaction
            self.transaction = transaction.transaction

            switch transaction.transaction {
            case let transaction as SaleTransaction:
                cardData = transaction.cardData
                start(transaction: transaction, entryModes: entryModes)
            case let transaction as AuthTransaction:
                cardData = transaction.cardData
                start(transaction: transaction, entryModes: entryModes)
            case let transaction as ReturnTransaction:
                cardData = transaction.cardData
                start(transaction: transaction, entryModes: entryModes)
            case let transaction as VerifyTransaction:
                cardData = transaction.cardData
                start(transaction: transaction, entryModes: entryModes)
            case let transaction as TokenizationTransaction:
                cardData = transaction.cardData
                start(transaction: transaction, entryModes: entryModes)
            default:
                transactionState = .error
                delegate.onError(error: .transactionNotSupported)
            }
        } else {
            self.transaction = transaction

            switch transaction {
            case let transaction as SaleTransaction:
                start(transaction: transaction, entryModes: entryModes)
            case let transaction as AuthTransaction:
                start(transaction: transaction, entryModes: entryModes)
            case let transaction as ReturnTransaction:
                start(transaction: transaction, entryModes: entryModes)
            case let transaction as VoidTransaction:
                start(transaction: transaction)
            case let transaction as ReversalTransaction:
                start(transaction: transaction)
            case let transaction as TipAdjustTransaction:
                start(transaction: transaction)
            case let transaction as CaptureTransaction:
                start(transaction: transaction)
            case let transaction as BatchCloseTransaction:
                start(transaction: transaction)
            case let transaction as VerifyTransaction:
                start(transaction: transaction, entryModes: entryModes)
            case let transaction as TokenizationTransaction:
                start(transaction: transaction, entryModes: entryModes)
            default:
                transactionState = .error
                delegate.onError(error: .transactionNotSupported)
            }
        }
    }
    
    func continueWithSurchargeAcceptance<T>(transaction: T,
                                            entryModes: [EntryMode],
                                            delegate: TransactionDelegate) {
        if let transaction = transaction as? Transaction {
            self.transaction = transaction
            
            self.delegate = delegate
            guard self.cardData == nil else {
                switch transaction {
                case let transaction as SaleTransaction:
                    
                    self.gateway.sale(transaction: transaction)
                case let transaction as AuthTransaction:
                   
                    self.gateway.auth(transaction: transaction)
                default:
                    ()
                }
                return
            }
            
            continueTransactionWithSurchargeAcceptance(transaction: transaction,
                                                       entryModes: entryModes,
                                                       delegate: delegate)
        }
       
    }

    func confirm(amount: Decimal) {
        defer {
            delegate?.onState(state: transactionState)
        }

        guard let terminal = terminal else {
            transactionState = .error
            delegate?.onError(error: .terminalNotConfigured)
            return
        }
        transactionState = .waitingForTerminal
        terminal.confirm(amount: amount)
    }

    func approveSaF() {
        switch transaction {
        case let transaction as SaleTransaction:
             safManager.store(transaction: transaction, delegate: self)
        case let transaction as AuthTransaction:
             safManager.store(transaction: transaction, delegate: self)
        case let transaction as ReturnTransaction:
             safManager.store(transaction: transaction, delegate: self)
        case let transaction as VerifyTransaction:
             safManager.store(transaction: transaction, delegate: self)
        case let transaction as TokenizationTransaction:
             safManager.store(transaction: transaction, delegate: self)
        default:
            transactionState = .error
            delegate?.onError(error: .transactionNotSupported)
        }
    }

    func listSaF(delegate: TransactionDelegate) {
        if gateway.gatewayConfig.supportSaf {
            self.delegate = delegate

            delegate.onListSaFComplete(transactions: safManager.listStoredTransaction())
        } else {
            delegate.onError(error: .gatewayFailure(message: "Saf is not supported in the config"))
        }
    }

    func select(aid: AID) {
        defer {
            delegate?.onState(state: transactionState)
        }

        guard let terminal = terminal else {
            transactionState = .error
            delegate?.onError(error: .terminalNotConfigured)
            return
        }

        guard transaction != nil else {
            transactionState = .error
            delegate?.onError(error: .transactionNotInProgress)
            return
        }

        transactionState = .waitingForTerminal
        terminal.select(aid: aid)
    }

    func postalCode(postalCode: String) {
        defer {
            delegate?.onState(state: transactionState)
        }

        if postalCode.isEmpty {
            delegate?.onError(error: .missingRequiredValue(message: "Missing Postal Code!"))
            return
        }

        if transactionState == .waitingForPostalCode {
            transactionState = .requestingOnlineProcessing

            var address = Address()
            address.postalCode = postalCode

            switch transaction {
            case var transaction as SaleTransaction:
                transaction.cardholderAddress = address
                gateway.sale(transaction: transaction)
            case var transaction as AuthTransaction:
                transaction.cardholderAddress = address
                gateway.auth(transaction: transaction)
            case var transaction as ReturnTransaction:
                transaction.cardholderAddress = address
                gateway.return(transaction: transaction)
            case var transaction as VerifyTransaction:
                transaction.cardholderAddress = address
                gateway.verify(transaction: transaction)
            case var transaction as TokenizationTransaction:
                transaction.cardholderAddress = address
                self.transaction = transaction
                gateway.tokenize(transaction: transaction)
            default:
                transactionState = .error
                delegate?.onError(error: .transactionNotSupported)
            }
        }
    }

    func cancelTransaction() {
        let states: [TransactionState] = [.cancelled, .cancelling, .cancel, .complete, .error]
        guard !states.contains(transactionState) else { return }
        transactionState = .cancel
        terminal?.cancelTransaction()
    }
    
    func deleteSafTransaction() {
        if let safTransaction = safTransaction {
            safManager.removeTransaction(transaction: safTransaction, delegate: self)
        }
    }
    
    func releaseDevice() {
        terminal?.releaseDevice()
    }
}

// MARK: GatewayDelegate
extension DefaultTransactionManager {

    func requestPostalCode(maskedPan: String,
                           expiryDate: String,
                           cardholderName: String?) {
        transactionState = .waitingForPostalCode

        delegate?.requestPostalCode(maskedPan: maskedPan,
                                    expiryDate: expiryDate,
                                    cardholderName: cardholderName)
    }

    func onResponse<T>(response: T) where T : TransactionResponse {
        defer {
            delegate?.onState(state: transactionState)
        }

        receivedGatewayResponse = true

        guard let reversal = response as? ReversalResponse else {
            transactionResponse = response

            if let cardResponse = transactionResponse as? CardTransactionResponse {
                if let safTransaction = safTransaction {
                    // remove processed store transaction
                    safManager.removeTransaction(transaction: safTransaction, delegate: self)
                } else {
                    process(response: cardResponse)
                }
            } else if response.transactionResult == .surchargeRequested {
                // MARK - Surcharge Request - call delegate for
                transactionState = .waitingForSurchargeAcceptance
                delegate?.onTransactionWaitingForSurchargeConfirmation(result: .surchargeRequested,
                                                                       response: response)
            } else {
                transactionState = .complete
                delegate?.onTransactionComplete(result: response.transactionResult ?? TransactionResult.success,
                                                response: response)
            }

            return
        }

        transactionState = .complete
        delegate?.onTransactionComplete(result: transactionResult ?? reversal.transactionResult ?? TransactionResult.success, response: reversal)
    }

    func onTimeOutOfNonEmvTransaction() {
        defer {
            delegate?.onState(state: transactionState)
        }

        reversalRequested = true
        performReversal(with: .deviceTimeOut, tlv: nil, response: self.hostResponse)
    }

    // Portico mapping currently, later change if required for Propay
    func onError(error: GatewayError, response: TransactionResponse?) {
        defer {
            delegate?.onState(state: transactionState)
        }

        receivedGatewayResponse = true
        var isTransactionReferenceResponse = false

        if (transactionResponse as? GatewayReferenceTransactionResponse) != nil {
            isTransactionReferenceResponse = true
        }

        switch error {
        case .hostTimeout:
            var hostResponse = HostProcessingResult()
            hostResponse.emvIssuerAuthCode = "8A025A33"
            hostResponse.transactionState = response?.transactionError == nil ? .gatewayTimeOutNoReply : .hostTimeout
            hostResponse.gatewayAuthCode = response?.gatewayTransactionId
            hostResponse.gatewayTxnId = response?.gatewayTransactionId
            transactionState = .waitingForTerminal
            if let terminal = terminal, !isTransactionReferenceResponse {
                self.hostResponse = hostResponse
                terminal.sendOnlineProcessingResult(response: hostResponse)

                if response?.transactionError == nil {
                    return
                }
            }

            transactionState = .complete
            delegate?.onTransactionComplete(result: .hostTimeout, response: response)
        case .hostNotReachable, .dnsFailed:
            // SafMode is not required for Portico at moment
            delegate?.onTransactionComplete(result: .networkError, response: response)
            transactionState = .complete
        case .permissionFailed(message: let message):
            delegate?.onError(error: .gatewayPermissionFailed(message: message))
            transactionState = .complete
        case .badRequest(message: let message):
            transactionState = .complete
            delegate?.onError(error: .missingRequiredValue(message: message))
        case .transactionFailed(message: let message):
            if let safTransaction = safTransaction {
                delegate?.onError(error: .safTransactionFailed(message: message, transactionID: safTransaction.clientTransactionId))
            } else {
                delegate?.onError(error: .transactionFailed(message: message))
                delegate?.onTransactionComplete(result: .fail, response: response)
            }
        case .requestFailed(message: let message, let errorCode):
            delegate?.onError(error: .gatewayFailure(message: message, errorCode: errorCode))
            delegate?.onTransactionComplete(result: .fail, response: response)
        case .trackReadFail:
            transactionState = .complete
            delegate?.onError(error: .trackReadFailed)
        default:
            break
        }

        terminal?.cancelTransaction()
    }

    func onError(error: GatewayError) {
        switch error {
        case .hostTimeout:
            var hostResponse = HostProcessingResult()
            hostResponse.emvIssuerAuthCode = "8A025A33"
            hostResponse.transactionState = .hostTimeout

            if let terminal = terminal {
                terminal.sendOnlineProcessingResult(response: hostResponse)
                return
            }

            delegate?.onError(error: .hostTimeout)
        case .hostNotReachable, .dnsFailed:
            let entryMode = getEntryMode()

            if gateway.gatewayConfig.supportSaf, entryMode != nil, safTransaction == nil {
                switch entryMode {
                case .token, .msr, .chipFallback:
                    transactionState = .waitingForSafApproval
                    delegate?.requestSaFApproval()
                    break
                default:
                    delegate?.onError(error: .hostNotReachable)
                    break
                }
            } else {
                delegate?.onError(error: .hostNotReachable)
            }
        case .permissionFailed(message: let message):
            delegate?.onError(error: .gatewayPermissionFailed(message: message))
        case .badRequest(message: let message):
            delegate?.onError(error: .missingRequiredValue(message: message))
        case .transactionFailed(message: let message):
            if let safTransaction = safTransaction {
                delegate?.onError(error: .safTransactionFailed(message: message, transactionID: safTransaction.clientTransactionId))
            } else {
                delegate?.onError(error: .transactionFailed(message: message))
            }
        case .requestFailed(message: let message, let errorCode):
            delegate?.onError(error: .gatewayFailure(message: message, errorCode: errorCode))
        default:
            break
        }

        terminal?.cancelTransaction()
    }

    private func getEntryMode() -> EntryMode? {
        let entryMode: EntryMode?

        switch transaction {
        case let transaction as CardTransaction:
            entryMode = transaction.cardData?.cardEntryMode
            break
        default:
            entryMode = nil
            break
        }

        return entryMode
    }

    private func process(response: CardTransactionResponse) {
        defer {
            delegate?.onState(state: transactionState)
        }

        switch cardData {
        case let any as AnyCardData:
            var cardResponse = response

            if (any.cardData as? ContactCardData) != nil  ||
                (any.cardData as? ContactlessCardData) != nil {
                guard let hostProcessingResult = response.hostProcessingResult else {
                    var hostProcessingResult = HostProcessingResult()
                    switch response.transactionResult ?? TransactionResult.terminated {
                    case .approved, .partialApproval, .success:
                        hostProcessingResult.transactionState = .onlineApproved
                        hostProcessingResult.emvIssuerAuthCode = "8A023030"
                    case .fail, .declined:
                        hostProcessingResult.transactionState = .onlineDecline
                        hostProcessingResult.emvIssuerAuthCode = "8A023035"
                    default:
                        break
                    }
                    sendOnlineProcessingResult(hostData: hostProcessingResult)
                    return
                }
                sendOnlineProcessingResult(hostData: hostProcessingResult)
            } else if let msr = any.cardData as? MSRCard {
                cardResponse.cardDataSourceType = msr.cardEntryMode
                cardResponse.cardholderName = msr.cardholderName
                cardResponse.maskedPan = msr.maskedPAN?.masked
                cardResponse.transactionType = transaction?.transactionType
                cardResponse.terminalType = gateway.gatewayConfig.terminalType.description
                cardResponse.merchantName = gateway.gatewayConfig.merchantName
                cardResponse.merchantAddress = gateway.gatewayConfig.merchantAddress
                cardResponse.merchantNumber = gateway.gatewayConfig.merchantNumber
                cardResponse.signatureAgreement = gateway.gatewayConfig.signatureAgreement
                cardResponse.acknowledgement = gateway.gatewayConfig.acknowledgement
                cardResponse.refundPolicy = gateway.gatewayConfig.refundPolicy
                transactionState = .complete
                delegate?.onTransactionComplete(result: response.transactionResult ?? .success, response: cardResponse)
            } else if let manual = any.cardData as? ManualCardData {
                cardResponse.cardDataSourceType = manual.cardEntryMode
                cardResponse.cardholderName = manual.cardholderName
                cardResponse.maskedPan = manual.maskedPAN?.masked
                cardResponse.transactionType = transaction?.transactionType
                cardResponse.terminalType = gateway.gatewayConfig.terminalType.description
                cardResponse.merchantName = gateway.gatewayConfig.merchantName
                cardResponse.merchantAddress = gateway.gatewayConfig.merchantAddress
                cardResponse.merchantNumber = gateway.gatewayConfig.merchantNumber
                cardResponse.signatureAgreement = gateway.gatewayConfig.signatureAgreement
                cardResponse.acknowledgement = gateway.gatewayConfig.acknowledgement
                cardResponse.refundPolicy = gateway.gatewayConfig.refundPolicy
                transactionState = .complete
                delegate?.onTransactionComplete(result: response.transactionResult ?? .success, response: cardResponse)
            } else if let tokenized = any.cardData as? TokenizedCardData {
                transactionState = .complete
                cardResponse.transactionType = transaction?.transactionType
                cardResponse.cardholderName = tokenized.cardholderName
                cardResponse.maskedPan = tokenized.maskedPAN
                delegate?.onTransactionComplete(result: response.transactionResult ?? .success, response: cardResponse)
            } else {
                transactionState = .complete
                cardResponse.transactionType = transaction?.transactionType
                delegate?.onTransactionComplete(result: response.transactionResult ?? .success, response: cardResponse)
            }
        case _ as ContactCardData, _ as ContactlessCardData:
            guard let hostProcessingResult = response.hostProcessingResult else {
                var hostProcessingResult = HostProcessingResult()
                switch response.transactionResult ?? TransactionResult.terminated {
                case .approved, .partialApproval, .success:
                    hostProcessingResult.transactionState = .onlineApproved
                    hostProcessingResult.emvIssuerAuthCode = "8A023030"
                case .fail, .declined:
                    hostProcessingResult.transactionState = .onlineDecline
                    hostProcessingResult.emvIssuerAuthCode = "8A023035"
                default:
                    break
                }
                sendOnlineProcessingResult(hostData: hostProcessingResult)
                return
            }
            sendOnlineProcessingResult(hostData: hostProcessingResult)
        default:
            transactionState = .complete
            delegate?.onTransactionComplete(result: response.transactionResult ?? .success, response: response)
        }
    }

    private func sendOnlineProcessingResult(hostData: HostProcessingResult) {
        guard let terminal = terminal else {
//            print("NO TERMINAL FOUND")
            performReversal(with: .deviceUnavailable, tlv: reversalTlv, response: self.hostResponse)

            return
        }

        transactionState = .waitingForTerminal
        terminal.sendOnlineProcessingResult(response: hostData)
    }

    private func performReversal(with reversalReason: ReversalReason,
                                 tlv: String?,
                                 response: HostProcessingResult?) {
        transactionState = .reversalInProgress
        var reversableAmount: UInt = 0
        var allowPartialAuth: Bool?
        if let cardTransaction = transaction as? CardTransaction {
            reversableAmount = cardTransaction.total ?? 0
            allowPartialAuth = cardTransaction.allowPartialAuth
        }

        let reversal = ReversalTransaction.reversal(clientTransactionId: transaction!.clientTransactionId,
                                                    gatewayTransactionId: response?.gatewayTxnId,
                                                    reversalReason: reversalReason,
                                                    posReferenceNumber: transaction?.posReferenceNumber,
                                                    amount: transactionResponse?.approvedAmount ?? reversableAmount,
                                                    tlv: tlv,
                                                    allowPartialAuth: allowPartialAuth)
        self.reversal = reversal
        gateway.reverse(transaction: reversal)
    }
}

/// TerminalTransactionDelegate
extension DefaultTransactionManager {

    func onState(state: TransactionState) {
        transactionState = state
        delegate?.onState(state: transactionState)
    }

    func requestAIDSelection(aids: [AID]) {
        guard let delegate = delegate else {
            terminal?.cancelTransaction()
            return
        }
        delegate.requestAIDSelection(aids: aids)
    }

    func requestAmountConfirmation(amount: Decimal?) {
        guard let delegate = delegate else {
            terminal?.cancelTransaction()
            return
        }
        delegate.requestAmountConfirmation(amount: amount)
    }
    
    func requestOnlineBinCheck(cardData: AnyCardData,
                               completion: @escaping ((_ response: SurchargeRequestedResponse?,
                                                       _ error: Error?) -> Void)) {
        guard let transaction = transaction as? CardTransaction else {
            transactionState = .error
            delegate?.onError(error: .missingRequiredValue(message: "transaction should be present"))
            return
        }
        
        gateway.binCardCheck(transaction: transaction, cardData: cardData, completion: completion)
    }

    func requestOnlineProcessing(cardData: AnyCardData, isSurcharge: Bool) {
        defer {
            delegate?.onState(state: transactionState)
        }
        self.cardData = cardData
        guard let transaction = transaction else {
            transactionState = .error
            delegate?.onError(error: .missingRequiredValue(message: "transaction should be present"))
            return
        }
        
        transactionState = .requestingOnlineProcessing
        wentOnline = true
        
        switch transaction {
        case var transaction as AuthTransaction:
            let surchargeFee: Decimal = transaction.surchargeFee ?? Decimal(SurchargeUtility.surchargeFee)
            let preTaxAmount: Decimal = transaction.preTaxAmount ?? Decimal(0)
            
            transaction.cardData = cardData
            let total = transaction.total
            
            if isSurcharge {
                let result = calculateSurcharge(
                    initialTotal: total?.amountInDecimal ?? Decimal(0),
                    preTaxAmount: preTaxAmount,
                    surchargeFee: surchargeFee
                )
                
                transaction.total = result.finalTotal
                transaction.surchargeAmtInfo = result.surchargeRate.stringValueSeparator
            } else {
                transaction.total = total
                transaction.surchargeAmtInfo = "0.00"
            }

            transaction.surchargeRequested = self.surchargeEligibility
            
            self.transaction = transaction
            gateway.auth(transaction: transaction)
        case var transaction as SaleTransaction:
            let surchargeFee: Decimal = transaction.surchargeFee ?? Decimal(SurchargeUtility.surchargeFee)
            let preTaxAmount: Decimal = transaction.preTaxAmount ?? Decimal(0)
            
            transaction.cardData = cardData
            if isSurcharge {
                let initialTotal = transaction.total
                
                if let isSurchargeEnabled = transaction.isSurchargeEnabled, isSurchargeEnabled {
                    let result = calculateSurcharge(
                        initialTotal: initialTotal?.amountInDecimal ?? Decimal(0),
                        preTaxAmount: preTaxAmount,
                        surchargeFee: surchargeFee
                    )
                    
                    transaction.total = result.finalTotal
                    transaction.surchargeAmtInfo = result.surchargeRate.stringValueSeparator
                } else {
                    transaction.total = initialTotal
                    transaction.surchargeAmtInfo = "0.00"
                }
            }

            transaction.surchargeRequested = self.surchargeEligibility
            
            self.transaction = transaction
            
            gateway.sale(transaction: transaction)
        case var transaction as ReturnTransaction:
            transaction.cardData = cardData
            self.transaction = transaction
            gateway.return(transaction: transaction)
        case var transaction as VerifyTransaction:
            transaction.cardData = cardData
            self.transaction = transaction
            gateway.verify(transaction: transaction)
        case var transaction as TokenizationTransaction:
            transaction.cardData = cardData
            self.transaction = transaction
            gateway.tokenize(transaction: transaction)
        default:
            transactionState = .error
            delegate?.onError(error: .transactionNotSupported)
            terminal?.cancelTransaction()
        }
    }
    
    func isSurchargeEnabled() -> Bool {
        if let transaction = self.transaction, let isSurchargeEnabled = transaction.isSurchargeEnabled {
            return isSurchargeEnabled
        }
        
        return false
    }
    
    func setSurchargeTimeOutError(isSurchargeTimeOutError: Bool, surchargeElibigility: SurchargeEligibility, completion: @escaping (() -> Void)) {

        self.isSurchargeTimeOutError = isSurchargeTimeOutError
        self.surchargeEligibility = surchargeElibigility
        completion()
    }

    func requestReversal(tlv: String?) {
        guard transaction as? VerifyTransaction == nil,
              transaction as? TokenizationTransaction == nil,
              transaction as? TipAdjustTransaction == nil,
              transaction as? BatchCloseTransaction == nil,
              transaction as? CaptureTransaction == nil else {
            return
        }
        transactionState = .reversal
        reversalRequested = true
        reversalTlv = tlv
    }

    func onICCTransactionComplete(result: TransactionResult, tlv: String?) {
        transactionResult = result
        defer {
            delegate?.onState(state: transactionState)
        }

        if transactionResult == .declined && wentOnline && !receivedGatewayResponse {
            transactionState = .processing
            return
        }

        guard !(reversalRequested && wentOnline) else {
            performReversal(with: result.reversalReason(), tlv: reversalTlv, response: self.hostResponse)

            return
        }

        transactionState = .complete
        if var cardResponse = transactionResponse as? CardTransactionResponse,
           let cardData = cardData as? AnyCardData {
            switch cardData.cardData {
            case let card as EMVCard:
                cardResponse.aid = card.aid
                cardResponse.applicationLabel = TLVUtility.hexToAscii(card.applicationLabel)
                cardResponse.tsi = card.tsi
                cardResponse.cvm = card.cvm
                cardResponse.cardDataSourceType = card.cardEntryMode
                cardResponse.maskedPan = card.maskedPAN?.trimmingTrailingCharacters(in: CharacterSet(charactersIn: "fF"))

                if let data = TLVDecoder.decode(withTLVString: card.tlvData) {
                    cardResponse.tvr = TLVUtility.findTLVObject(.terminalVerificationResults, fromArray: data)?.value
                    cardResponse.iac = TLVUtility.findTLVObject(.issuerActionDenial, fromArray: data)?.value
                    cardResponse.iad = TLVUtility.findTLVObject(.issuerAppData, fromArray: data)?.value
                    cardResponse.applicationCryptogram = TLVUtility.findTLVObject(.applicationCryptogram, fromArray: data)?.value

                    if let value = TLVUtility.findTLVObject(.cryptogramInformationData, fromArray: data)?.value, let applicationCryptogramType = Int(value) {
                        cardResponse.applicationCryptogramType = ApplicationCryptogramType(rawValue: applicationCryptogramType)?.description
                    }

                    // CardholderName
                    if let cardholderName = card.cardholderName, !cardholderName.isEmpty {
                        cardResponse.cardholderName = TLVUtility.hexToAscii(cardholderName)?.trimmingCharacters(in: .whitespaces)
                    } else {
                        let hexValue = TLVUtility.findTLVObject(.cardholderName, fromArray: data)?.value
                        cardResponse.cardholderName = TLVUtility.hexToAscii(hexValue)?.trimmingCharacters(in: .whitespaces)
                    }

                    cardResponse.applicationPANSequenceNumber = TLVUtility.findTLVObject(.panSequenceNumber, fromArray: data)?.value
                    if let versionNumber = TLVUtility.findTLVObject(.applicationVersionNumber, fromArray: data)?.value {
                        cardResponse.applicationVersionNumber = versionNumber
                    } else {
                        cardResponse.applicationVersionNumber = TLVUtility.findTLVObject(.applicationVersionNumberTerminal, fromArray: data)?.value
                    }

                    cardResponse.cid = TLVUtility.findTLVObject(.cryptogramInformationData, fromArray: data)?.value
                    cardResponse.applicationTransactionCounter = TLVUtility.findTLVObject(.applicationTransactionCounter, fromArray: data)?.value
                    cardResponse.unpredictableNumber = TLVUtility.findTLVObject(.unpredictableNumber, fromArray: data)?.value
                    cardResponse.transactionSequenceCounter = TLVUtility.findTLVObject(.transactionSequenceNumber, fromArray: data)?.value
                }
            case let msr as MSRCardData:
                cardResponse.cardDataSourceType = msr.cardEntryMode
                cardResponse.cardholderName = msr.cardholderName
                cardResponse.maskedPan = msr.maskedPAN
            default:
                break
            }

            cardResponse.transactionType = transaction?.transactionType
            cardResponse.terminalType = gateway.gatewayConfig.terminalType.description
            cardResponse.merchantName = gateway.gatewayConfig.merchantName
            cardResponse.merchantAddress = gateway.gatewayConfig.merchantAddress
            cardResponse.merchantNumber = gateway.gatewayConfig.merchantNumber
            cardResponse.acknowledgement = gateway.gatewayConfig.acknowledgement
            cardResponse.refundPolicy = gateway.gatewayConfig.refundPolicy

            // Signature line
            switch cardData.cardData {
            case let card as EMVCard:
                cardResponse.manualSignature = card.cvm == nil ||
                    TerminalTender.cardholderAuthenticationMethodfromTlv(card.cvm) == .manualSignature
                break
            default:
                // Show signature line if the approved amount is greater than the config's signatureThresholdAmount.
                if let approvedAmount = cardResponse.approvedAmount,
                   approvedAmount > gateway.gatewayConfig.signatureThresholdAmount.penniesValue {
                    cardResponse.manualSignature = true
                }
                break
            }

            if cardResponse.manualSignature {
                cardResponse.signatureAgreement = gateway.gatewayConfig.signatureAgreement
            }

            delegate?.onTransactionComplete(result: result, response: cardResponse)
        } else {
            delegate?.onTransactionComplete(result: result, response: transactionResponse)
        }
    }

    func onICCTransactionCancelled() {
        if transactionState != .waitingForSafApproval {
            transactionState = .cancelled
            delegate?.onState(state: transactionState)
            delegate?.onTransactionCancelled()
        }
    }

    func onError(error: TransactionError) {
        transactionState = .error
        delegate?.onError(error: error)
    }

    func onError(terminalError: TerminalError) {
        onError(error: terminalError.transcationError())
    }
    
    func onTransactionWaitingForSurchargeConfirmation(result: TransactionResult,
                                                      response: TransactionResponse?) {
        delegate?.onTransactionWaitingForSurchargeConfirmation(result: result, response: response)
    }
}

/// SaFDelegate callbacks
extension DefaultTransactionManager {
    func onTransactionStored(response: TransactionResponse) {
        delegate?.onTransactionComplete(result: .offlineApproved, response: response)
    }

    func onDeletedExpiredTransactions(deletedTransactions: [ProcessSaF]) {
        delegate?.onDeletedTransactionsComplete(deletedTransactions: deletedTransactions)
    }

    func onTransactionRemoved() {
        self.safTransaction = nil
        if let cardResponse = transactionResponse as? CardTransactionResponse {
            process(response: cardResponse)
        }
    }

    func onError(error: SaFError) {
        delegate?.onError(error: TransactionError.transactionNotSupported)
    }
}

/// Logic to handle starting transactions
extension DefaultTransactionManager {

    private func start(transaction: SaleTransaction, entryModes: [EntryMode]) {

        guard transaction.cardData == nil else {
            transactionState = .processing
            cardData = transaction.cardData
            gateway.sale(transaction: transaction)
            return
        }
        guard let terminal = terminal else {
            transactionState = .error
            delegate?.onError(error: .terminalNotConfigured)
            return
        }
        guard terminal.connected else {
            transactionState = .error
            delegate?.onError(error: .terminalNotConnnected)
            return
        }
        transactionState = .started

        terminal.start(amount: transaction.total?.amountInDecimal,
                       transactionType: .Sale,
                       entryModes: entryModes,
                       delegate: self)
    }
    
    private func continueTransactionWithSurchargeAcceptance<T>(transaction: T,
                                                               entryModes: [EntryMode],
                                                               delegate: TransactionDelegate) {
        
        switch transaction {
        case var transaction as SaleTransaction:
            let surchargeFee: Decimal = transaction.surchargeFee ?? Decimal(SurchargeUtility.surchargeFee)
            let preTaxAmount: Decimal = transaction.preTaxAmount ?? Decimal(0)
            transactionState = .started
            let total = transaction.total
            
            if let isSurchargeEnabled = transaction.isSurchargeEnabled, isSurchargeEnabled {
                let result = calculateSurcharge(
                    initialTotal: total?.amountInDecimal ?? Decimal(0),
                    preTaxAmount: preTaxAmount,
                    surchargeFee: surchargeFee
                )
                
                transaction.total = result.finalTotal
                transaction.surchargeAmtInfo = result.surchargeRate.stringValueSeparator
            } else {
                transaction.total = total
                transaction.surchargeAmtInfo = "0.00"
            }
            
            
            terminal?.confirmSurcharge(amount: transaction.total?.amountInDecimal ?? 0.00)
            
        case var transaction as AuthTransaction:
            let surchargeFee: Decimal = transaction.surchargeFee ?? Decimal(SurchargeUtility.surchargeFee)
            let preTaxAmount: Decimal = transaction.preTaxAmount ?? Decimal(0)
            transactionState = .started
            let total = transaction.total
            
            if let isSurchargeEnabled = transaction.isSurchargeEnabled, isSurchargeEnabled {
                let result = calculateSurcharge(
                    initialTotal: total?.amountInDecimal ?? Decimal(0),
                    preTaxAmount: preTaxAmount,
                    surchargeFee: surchargeFee
                )
                                
                transaction.total = result.finalTotal
                transaction.surchargeAmtInfo = result.surchargeRate.stringValueSeparator
            } else {
                transaction.total = total
                transaction.surchargeAmtInfo = "0.00"
            }
           
            if let cardData = self.cardData {
                transaction.cardData = AnyCardData(cardData: cardData)
            }
            if case .manualCard = terminal?.authType {
                
                gateway.auth(transaction: transaction)
            } else {
                
                terminal?.confirmSurcharge(amount: transaction.total?.amountInDecimal ?? 0.00)
            }
        default:
            transactionState = .error
            delegate.onError(error: .transactionNotSupported)
        }
        
        transactionState = .started
    }
    
    // TODO: - Will Remove this in future
    private func addingSurchargeAmountToTotal(_ total: Decimal?, _ surchargePercent: Decimal, _ preTaxAmount: Decimal) -> UInt? {
        guard var total = total else { return 0 }
       
        if preTaxAmount > 0 {
            total = (total - preTaxAmount)
        }
        
        let surchargeFee = self.calculateSurchargePercent(total, surchargePercent)
        
        let surchargeAmountFee: Decimal = total + surchargeFee

        return UInt(surchargeAmountFee.penniesValue)
    }

    // TODO: - Will Remove this in future
    private func getSurchargeAmount(_ total: Decimal?, _ surchargePercent: Decimal, _ preTaxAmount: Decimal) -> String? {
        guard var total = total else { return "" }
        
        if preTaxAmount > 0 {
            total = (total - preTaxAmount)
        }
        
        let surchargeFee = self.calculateSurchargePercent(total, surchargePercent)
        
        return surchargeFee.stringValueSeparator
    }
    
    // TODO: - Will Remove this in future
    private func calculateSurchargePercent(_ total: Decimal?, _ surchargePercent: Decimal?) -> Decimal {
        guard let total = total, let surchargePercent = surchargePercent else {
            return 0.0
        }
        return ((total * surchargePercent) / 100).rounded(2, .plain)
    }

    private func start(transaction: AuthTransaction, entryModes: [EntryMode]) {
        guard transaction.cardData == nil else {
            terminal?.authType = .manualCard
            transactionState = .processing
            cardData = transaction.cardData
            
            guard let onlineCheckingCardData = transaction.cardData else {
                gateway.auth(transaction: transaction)
                return
            }
            
            // IF THE BUILDER SAYS isSurchargeEnabled we continue, if not, we will do the auth either way.
            guard let isSurchargeEnabled = transaction.isSurchargeEnabled, isSurchargeEnabled == true else {
                gateway.auth(transaction: transaction)

                return
            }
            
            // if surcharge is enabled
            
            requestOnlineBinCheck(cardData: onlineCheckingCardData) { [weak self] response, error in
                guard let self = self else { return }
                
                if let error {
                   
                    setSurchargeTimeOutError(isSurchargeTimeOutError: true, surchargeElibigility: .U) {
                        var currentTransaction = transaction
                        currentTransaction.surchargeRequested = .U
                        currentTransaction.cardData = AnyCardData(cardData: onlineCheckingCardData)
                        self.gateway.auth(transaction: currentTransaction)
                    }
                    return
                }
                
                if let response = response,
                   let surchargeRequired = response.surchargeRequested, case .Y = surchargeRequired {
                   
                    setSurchargeTimeOutError(isSurchargeTimeOutError: false, surchargeElibigility: .Y) {
                        self.onState(state: .waitingForSurchargeAcceptance)
                        self.onTransactionWaitingForSurchargeConfirmation(result: .surchargeRequested,
                                                                          response: response)
                    }
                } else {
                    setSurchargeTimeOutError(isSurchargeTimeOutError: false, surchargeElibigility: .N) {
                        self.gateway.auth(transaction: transaction)
                    }
                }
            }
//            gateway.auth(transaction: transaction)
            
            return
        }
        guard var terminal = terminal else {
            transactionState = .error
            delegate?.onError(error: .terminalNotConfigured)
            return
        }
        guard terminal.connected else {
            transactionState = .error
            delegate?.onError(error: .terminalNotConnnected)
            return
        }
        transactionState = .started
        terminal.authType = .cardReader
        /// TODO: This logic **will** l change when surchaging goes in
        terminal.start(amount: transaction.total?.amountInDecimal,
                       transactionType: .Auth,
                       entryModes: entryModes,
                       delegate: self)
    }

    private func start(transaction: ReturnTransaction, entryModes: [EntryMode]) {
        guard transaction.cardData == nil, (transaction.gatewayTransactionId?.isEmpty ?? true) else {
            transactionState = .processing
            cardData = transaction.cardData
            gateway.return(transaction: transaction)
            return
        }
        guard let terminal = terminal else {
            transactionState = .error
            delegate?.onError(error: .terminalNotConfigured)
            return
        }
        guard terminal.connected else {
            transactionState = .error
            delegate?.onError(error: .terminalNotConnnected)
            return
        }
        transactionState = .started

        terminal.start(amount: transaction.total?.amountInDecimal,
                       transactionType: .Return,
                       entryModes: entryModes,
                       delegate: self)
    }

    private func start(transaction: TokenizationTransaction, entryModes: [EntryMode]) {
        guard transaction.cardData == nil else {
            transactionState = .processing
            cardData = transaction.cardData
            gateway.tokenize(transaction: transaction)
            return
        }
        guard let terminal = terminal else {
            transactionState = .error
            delegate?.onError(error: .terminalNotConfigured)
            return
        }
        guard terminal.connected else {
            transactionState = .error
            delegate?.onError(error: .terminalNotConnnected)
            return
        }

        transactionState = .started
        terminal.start(amount: nil, transactionType: .Tokenize, entryModes: entryModes, delegate: self)
    }

    private func start(transaction: VerifyTransaction, entryModes: [EntryMode]) {
        guard transaction.cardData == nil else {
            transactionState = .processing
            cardData = transaction.cardData
            gateway.verify(transaction: transaction)
            return
        }
        guard let terminal = terminal else {
            transactionState = .error
            delegate?.onError(error: .terminalNotConfigured)
            return
        }
        guard terminal.connected else {
            transactionState = .error
            delegate?.onError(error: .terminalNotConnnected)
            return
        }

        transactionState = .started
        terminal.start(amount: nil, transactionType: .Verify, entryModes: entryModes, delegate: self)
    }

//    private func start(transaction: CaptureTransaction) {
//        transactionState = .processing
//        gateway.capture(transaction: transaction)
//    }
    
    // MARK: TODO: - CAPTURE
    fileprivate func getCurrentTransactionAmount(_ total: UInt,
                                                surchargeFee: Decimal?,
                                                preTaxAmount: Decimal = 0.00) -> String {
        
        let result = calculateSurcharge(
            initialTotal: total.amountInDecimal,
            preTaxAmount: preTaxAmount,
            surchargeFee: surchargeFee ?? SurchargeUtility.surchargeFee.amountInDecimal
        )
        
        return String(result.finalTotal)
    }
    
    fileprivate func getOriginalTransactionAmount(_ amount: String) -> String {
        return String(amount)
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: "")
    }
    
    private func start(transaction: CaptureTransaction) {
        // MARK: ToDo: - Get Report Transaction Id.
        // Check the surgarge amount.
        // Original amount is diff than the capture amount, will you approve the surcharge again?
        // if capture amount is equal from auth amount, we get surchargeAmount and add to capture amount.
        // if capture amount is not equal from auth amount, we should decline the capture.
        
//        transactionState = .processing
//        self.gateway.capture(transaction: transaction)
        guard let isSurchargeEnabled = transaction.isSurchargeEnabled, isSurchargeEnabled == true else {
            
            transactionState = .processing
            self.gateway.capture(transaction: transaction)
            return
        }
        var currentTransaction = transaction
        if let transactionId = currentTransaction.gatewayTransactionId {

            gateway.getTransactionDetail(transactionId: transactionId) { gpTransactionSummary, error in

                if error != nil {

                    self.transactionState = .error
                    self.delegate?.onError(error: .hostTimeout)
                    return
                }

                if let gpTransactionSummary, gpTransactionSummary.surchargeAmount != nil {
                    let surchargeFee = currentTransaction.surchargeFee ?? SurchargeUtility.surchargeFee.amountInDecimal
                    let currentTransactionAmount = self.getCurrentTransactionAmount(currentTransaction.total ?? 0,
                                                                                   surchargeFee: surchargeFee)
                    let preTaxAmount: Decimal = currentTransaction.preTaxAmount ?? 0
                    let originalTransactionAmount = self.getOriginalTransactionAmount(gpTransactionSummary.amount)

                    if originalTransactionAmount == currentTransactionAmount {
                        
                        let total = currentTransaction.total
                        if isSurchargeEnabled {
                            let result = self.calculateSurcharge(
                                initialTotal: total?.amountInDecimal ?? Decimal(0),
                                preTaxAmount: preTaxAmount,
                                surchargeFee: surchargeFee
                            )
                            
                            currentTransaction.total = result.finalTotal
                            currentTransaction.surchargeAmtInfo = result.surchargeRate.stringValueSeparator
                        } else {
                            currentTransaction.total = total
                            currentTransaction.surchargeAmtInfo = "0.00"
                        }

                        self.transactionState = .processing
                        self.gateway.capture(transaction: currentTransaction)

                    } else {

                        self.transactionState = .error
                        self.delegate?.onError(error: .gatewayFailure(message: "Transaction declined due the difference between original amount and capture amount"))

                        print("Transaction declined due the difference between original amount and capture amount")

                        return
                    }
                } else {
                    self.transactionState = .processing
                    self.gateway.capture(transaction: currentTransaction)
                }
            }
        } else {
            transactionState = .error
            delegate?.onError(error: .transactionFailed(message: "Gateway Transaction ID didn't find"))
            return
        }
    }

    private func start(transaction: VoidTransaction) {
        transactionState = .processing
        gateway.void(transaction: transaction)
    }

    private func start(transaction: ReversalTransaction) {
        transactionState = .processing
        gateway.reverse(transaction: transaction)
    }

    private func start(transaction: BatchCloseTransaction) {
        transactionState = .processing
        gateway.batchClose(transaction: transaction)
    }

    private func start(transaction: TipAdjustTransaction) {
        transactionState = .processing
        guard let isSurchargeEnabled = transaction.isSurchargeEnabled, isSurchargeEnabled == true else {

            transactionState = .processing
            self.gateway.tipAdjust(transaction: transaction)
            return
        }
        
        var currentTransaction = transaction
        if let transactionId = currentTransaction.gatewayTransactionId {

            gateway.getTransactionDetail(transactionId: transactionId) { gpTransactionSummary, error in

                if error != nil {

                    self.transactionState = .error
                    self.delegate?.onError(error: .hostTimeout)
                    return
                }

                if let gpTransactionSummary, gpTransactionSummary.surchargeAmount != nil {
                    
                    currentTransaction.surchargeAmtInfo = gpTransactionSummary.surchargeAmount
                    
                    if let total = currentTransaction.total, let surchargeAmtInfo = gpTransactionSummary.surchargeAmount {
                        currentTransaction.total = total + surchargeAmtInfo.amountInPennies
                    }
                    self.transactionState = .processing
                    self.gateway.tipAdjust(transaction: currentTransaction)
                } else {
                    self.transactionState = .processing
                    self.gateway.tipAdjust(transaction: currentTransaction)
                }
            }
        } else {
            transactionState = .error
            delegate?.onError(error: .transactionFailed(message: "Gateway Transaction ID not found!"))
            return
        }
        
        
//        gateway.tipAdjust(transaction: transaction)
    }
}

// MARK: - Surcharge + PreTax Calculation
extension DefaultTransactionManager {
    func calculateSurcharge(
        initialTotal: Decimal,
        preTaxAmount: Decimal,
        surchargeFee: Decimal
    ) -> (surchargeRate: Decimal, finalTotal: UInt) {
        /// Deduct `Initial Total` to `Pre-tax` value
        let deductedTotal = initialTotal - preTaxAmount
        
        /// Calculate the surcharge base in `deductedTotal` value
        var roundedValue = surchargeFee
        var roundedSurchargeFee = Decimal()
        NSDecimalRound(&roundedSurchargeFee, &roundedValue, 2, .plain)
        let surchargeFeeInFraction = roundedSurchargeFee / Decimal(100)
        let surchargeRate = (deductedTotal * surchargeFeeInFraction).rounded(2, .down)
        
        let finalTotal = (initialTotal + surchargeRate).penniesValueUInt
        
        return (surchargeRate, finalTotal)
    }
}

extension Transaction {
    var transactionType: TransactionType? {
        switch type(of: self) {
        case is SaleTransaction.Type: return .Sale
        case is AuthTransaction.Type: return .Auth
        case is ReturnTransaction.Type: return .Return
        case is TokenizationTransaction.Type: return .Tokenize
        case is VerifyTransaction.Type: return .Verify
        case is CaptureTransaction.Type: return .Capture
        case is VoidTransaction.Type: return .Void
        case is BatchCloseTransaction.Type: return .BatchClose
        case is TipAdjustTransaction.Type: return .TipAdjust
        default: return nil
        }
    }
}
