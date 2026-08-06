//
//  GMSManager.swift
//  ios-device-lib
//

import Foundation
import os

public class GMSManager {
    
    public static let shared = GMSManager()
    
    // MARK: Variables
    private var terminal: Terminal?
    private var terminalOTADelegate: TerminalOTAManagerDelegate?
    private var terminalSettingsDelegate: TerminalSettingsUpdateDelegate?
    private var gateway: Gateway?
    private var gatewayConfig: GatewayConfig?
    private var transactionManager: TransactionManager?
    public weak var connectionDelegate: ConnectionDelegate?
    public weak var transactionDelegate: TransactionDelegate?
    public weak var searchDelegate: SearchDelegate?
    public var transactionState: TransactionState = .waitingForConfiguration
    public var terminalInfo: TerminalInfo?
    public var terminalConnected: Bool {
        guard let terminalInfo = terminalInfo else { return false }
        return terminalInfo.connected
    }
    
    private init() {
    }
    
    public func configure(gatewayConfig: GatewayConfig, connectionInterface: RUACommunicationInterface? = nil) throws {
        self.gatewayConfig = gatewayConfig
        self.transactionManager = nil

        guard var terminalConfig = gatewayConfig.supportedTerminals[gatewayConfig.terminalType] else {
            throw GatewayEnvironment.ConfigurationError.decodeFailed(debugMessage: "Error: Gateway does not support \(gatewayConfig.terminalType)")
        }

        switch gatewayConfig {
        case let config as PorticoConfig:
            gateway = PorticoGateway(config: config)
            terminalConfig.terminalOnlineProcessTimeout = config.terminalOnlineProcessTimeout
        default:
            throw GatewayEnvironment.ConfigurationError.decodeFailed(debugMessage: "Error: Gateway Configuration not supported")
        }

        switch gatewayConfig.terminalType {
        case .none:
            transactionState = .ready
            return

        case .bbpos_wisecube, .bbpos_c2x:
            terminal = BBPOSTerminal(terminal: gatewayConfig.terminalType, config: terminalConfig)
            transactionState = .ready
            if let terminalInfo = terminalInfo, let terminal = terminal as? BBPOSTerminal {
                terminal.selectedTerminal = terminalInfo
            }

        case .ingencio_moby3000, .ingencio_g4x_g5x, .ingenico_moby5500:
            terminal = IngenicoTerminal(terminal: gatewayConfig.terminalType,
                                        isDebug: gatewayConfig.isDebug,
                                        config: terminalConfig,
                                        connectionInterface: connectionInterface)
            transactionState = .ready

        case .unimag:
            break
            
        default:
            break
        }
    }

    public func requestReadTerminalSetting(settingType: TerminalSettingType, delegate: TerminalSettingsUpdateDelegate) {
        guard let terminal = self.terminal else {
            delegate.onError(error: .terminalNotConfigured)
            return
        }
        terminalSettingsDelegate = delegate
        DispatchQueue.global(qos: .userInitiated).async { [unowned self] in
            terminal.readTerminalSetting(settingType: settingType, delegate: self)
        }
    }
    
    public func requestUpdateTerminalSetting(settingType: TerminalSettingType, value: Int, delegate: TerminalSettingsUpdateDelegate) {
        let terminalSettingMinValue = 0
        let terminalSettingMaxValue = 255
        guard let terminal = self.terminal else {
            delegate.onError(error: .terminalNotConfigured)
            return
        }
        terminalSettingsDelegate = delegate
        if value > terminalSettingMaxValue || value < terminalSettingMinValue {
            terminalSettingsDelegate?.onReturnUpdateSetting(settingType: settingType, result: .invalidValue)
        } else {
            let dol = String(value, radix: 16) //int to hex string
            DispatchQueue.global(qos: .userInitiated).async { [unowned self] in
                terminal.updateTerminalSetting(settingType: settingType, dol: dol, delegate: self)
            }
        }
    }
    
    public func requestTerminalVersionData(delegate: TerminalOTAManagerDelegate) {
        guard let terminal = self.terminal else {
            delegate.onError(error: .terminalNotConfigured)
            return
        }
        terminalOTADelegate = delegate
        DispatchQueue.global(qos: .userInitiated).async { [unowned self] in
            terminal.terminalVersionData(delegate: self)
        }
    }
    
    public func requestAvailableOTAVersionsListFor(type: TerminalOTAUpdateType, delegate: TerminalOTAManagerDelegate) {
        guard let terminal = self.terminal else {
            delegate.onError(error: .terminalNotConfigured)
            return
        }
        terminalOTADelegate = delegate
        DispatchQueue.global(qos: .userInitiated).async { [unowned self] in
            terminal.listAvailableOTAVersionsFor(type: type, delegate: self)
        }
    }
    
    public func setVersionDataFor(type: TerminalOTAUpdateType, versionString: String, delegate: TerminalOTAManagerDelegate) {
        guard let terminal = self.terminal else {
            delegate.onError(error: .terminalNotConfigured)
            return
        }
        terminalOTADelegate = delegate
        DispatchQueue.global(qos: .userInitiated).async { [unowned self] in
            terminal.setTerminalVersionsFor(type: type, versionString: versionString, delegate: self)
        }
    }
    
    public func requestToStartUpdateFor(type: TerminalOTAUpdateType, delegate: TerminalOTAManagerDelegate) {
        guard let terminal = self.terminal else {
            delegate.onError(error: .terminalNotConfigured)
            return
        }
        terminalOTADelegate = delegate
        DispatchQueue.global(qos: .userInitiated).async { [unowned self] in
            terminal.startOTAUpdateProcess(type: type, selectedVersion: "", delegate: self)
        }
    }
    
    public func listSaF(delegate: TransactionDelegate) {
        guard let gateway = self.gateway else {
            DispatchQueue.main.async {
                delegate.onError(error: .gatewayNotConfigured)
            }
            return 
        }
        
        guard transactionManager == nil else {
            DispatchQueue.main.async {
                delegate.onError(error: .transactionInProgress)
            }
            return
        }
        
        transactionManager = DefaultTransactionManager(gateway: gateway, terminal: terminal)
        transactionDelegate = delegate
        guard let transactionManager = transactionManager else {
            if #available(iOS 12.0, *) {
                os_log(.error, "Unexpectly found nil for transaction manager")
            }
            
            DispatchQueue.main.async { [unowned self] in
                self.transactionDelegate?.onError(error: .transactionNotInProgress)
            }
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
             transactionManager.listSaF(delegate: self)
        }
       
    }
    
    public func search(delegate: SearchDelegate) {
        guard let terminal = self.terminal else {
            delegate.onError(error: .terminalNotConfigured)
            return
        }
        searchDelegate = delegate
        DispatchQueue.global(qos: .userInitiated).async { [unowned self] in
            terminal.search(delegate: self)
        }
    }
    
    public func cancelSearch() {
        guard let terminal = self.terminal else {
            searchDelegate?.onError(error: .terminalNotConfigured)
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            terminal.cancelSearch()
        }
    }
    
    public func connect(terminalInfo: TerminalInfo, delegate: ConnectionDelegate) {
        guard let terminal = self.terminal else {
            DispatchQueue.main.async {
                delegate.onError(error: .terminalNotConfigured)
            }
            return
        }
        connectionDelegate = delegate
        DispatchQueue.global(qos: .userInitiated).async {
            terminal.connect(terminalInfo: terminalInfo, delegate: self)
        }
    }
    
    public func disconnect() {
        guard let terminal = self.terminal else {
            DispatchQueue.main.async { [unowned self] in
                self.connectionDelegate?.onError(error: .terminalNotConfigured)
            }
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            terminal.disconnect()
        }
    }
    
//    public func startCheckingForBinCard(cardData: AnyCardData,
//                                        completion: @escaping ((_ response: SurchargeRequestedResponse?,
//                                                                _ error: Error?) -> Void)) {
//        transactionManager?.requestOnlineBinCheck(cardData: cardData, completion: completion)
//    }
    
    public func start<T: Transaction>(transaction: T, entryModes: [EntryMode] = EntryMode.allCases, delegate: TransactionDelegate) {
        guard let gateway = self.gateway else {
            DispatchQueue.main.async {
                delegate.onError(error: .gatewayNotConfigured)
            }
            return
        }
        
        guard transactionManager == nil else {
            DispatchQueue.main.async {
                delegate.onError(error: .transactionInProgress)
            }
            return
        }
        
        transactionManager = DefaultTransactionManager(gateway: gateway, terminal: terminal)
        transactionDelegate = delegate
        DispatchQueue.global(qos: .userInitiated).async { [unowned self] in
            guard let transactionMangaer = self.transactionManager else {
                if #available(iOS 12.0, *) {
                    os_log(.error, "Unexpectly found nil for transaction manager")
                }
                DispatchQueue.main.async {
                    delegate.onError(error: .transactionNotInProgress)
                }
                return
            }
           
            transactionMangaer.start(transaction: transaction, entryModes: entryModes, delegate: self)
        }
    }
    
    public func confirmSurcharge<T: Transaction>(transaction: T, entryModes: [EntryMode] = EntryMode.allCases,
                                                 delegate: TransactionDelegate) {
       
        guard let gateway = self.gateway else {
            DispatchQueue.main.async {
                delegate.onError(error: .gatewayNotConfigured)
            }
            
            return
        }
        
        transactionManager = DefaultTransactionManager(gateway: gateway, terminal: terminal)
        transactionDelegate = delegate
        DispatchQueue.global(qos: .userInitiated).async { [unowned self] in
            guard let _ = self.transactionManager else {
                if #available(iOS 12.0, *) {
                    os_log(.error, "Unexpectly found nil for transaction manager")
                }
                DispatchQueue.main.async {
                    delegate.onError(error: .transactionNotInProgress)
                }
                return
            }
            
            transactionManager?.continueWithSurchargeAcceptance(transaction: transaction,
                                                                entryModes: entryModes,
                                                                delegate: self)
        }
    }
    
    public func confirm(amount: Decimal) {
        guard let transactionManager = transactionManager else {
            if #available(iOS 12.0, *) {
                os_log(.error, "Unexpectly found nil for transaction manager")
            }
            transactionDelegate?.onError(error: .transactionNotInProgress)
            return
        }
        transactionManager.confirm(amount: amount)
    }
    
    public func approveSaF() {
        guard let transactionManager = transactionManager else {
            if #available(iOS 12.0, *) {
                os_log(.error, "Unexpectly found nil for transaction manager")
            }
            
            DispatchQueue.main.async { [unowned self] in
                self.transactionDelegate?.onError(error: .transactionNotInProgress)
            }
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            transactionManager.approveSaF()
        }
    }

    public func postalCode(postalCode: String) {
        guard let transactionManager = transactionManager else {
            if #available(iOS 12.0, *) {
                os_log(.error, "Unexpectly found nil for transaction manager")
            }

            transactionDelegate?.onError(error: .transactionNotInProgress)
            return
        }
        transactionManager.postalCode(postalCode: postalCode)
    }
    
    public func select(aid: AID) {
        guard let transactionManager = transactionManager else {
            if #available(iOS 12.0, *) {
                os_log(.error, "Unexpectly found nil for transaction manager")
            }
            transactionDelegate?.onError(error: .transactionNotInProgress)
            return
        }
        transactionManager.select(aid: aid)
    }
    
    public func cancelTransaction() {
        guard let transactionManager = transactionManager else {
            if #available(iOS 12.0, *) {
                os_log(.error, "Unexpectly found nil for transaction manager")
            }
            DispatchQueue.main.async { [unowned self] in
                self.transactionDelegate?.onError(error: .transactionNotInProgress)
            }
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            transactionManager.cancelTransaction()
        }
    }
    
    public func deleteSafTransaction() {
        guard let transactionManager = transactionManager else {
            if #available(iOS 12.0, *) {
                os_log(.error, "Unexpectly found nil for transaction manager")
            }
            DispatchQueue.main.async { [unowned self] in
                self.transactionDelegate?.onError(error: .transactionNotInProgress)
            }
            return
        }
        transactionManager.deleteSafTransaction()
        self.transactionManager = nil
    }
    
    public func releaseDevice() {
        guard let terminal = self.terminal else {
            DispatchQueue.main.async {
                self.transactionDelegate?.onError(error: .transactionNotInProgress)
            }
            return
        }
       
        DispatchQueue.global(qos: .userInitiated).async {
            terminal.releaseDevice()
        }
    }
}

extension GMSManager: SearchDelegate {
    public func deviceFound(terminalInfo: TerminalInfo) {
        if #available(iOS 12.0, *) {
            os_log(.debug, "device found: %@", terminalInfo.description)
        }
        DispatchQueue.main.async { [unowned self] in
            self.searchDelegate?.deviceFound(terminalInfo: terminalInfo)
        }
    }
    
    public func onSearchComplete() {
        if #available(iOS 12.0, *) {
            os_log(.debug, "device search complete")
        }
        
        DispatchQueue.main.async { [unowned self] in
            self.searchDelegate?.onSearchComplete()
        }
    }
    
    public func onError(error: SearchError) {
        if #available(iOS 12.0, *) {
            os_log(.error, "device search error: %@", error.localizedDescription)
        }
        DispatchQueue.main.async { [unowned self] in
            self.searchDelegate?.onError(error: error)
        }
    }
}

extension GMSManager: ConnectionDelegate {
    public func onConnected(terminalInfo: TerminalInfo) {
        self.terminalInfo = terminalInfo

        DispatchQueue.main.async { [unowned self] in
            self.connectionDelegate?.onConnected(terminalInfo: terminalInfo)
        }
    }
    
    public func onDisconnected(terminalInfo: TerminalInfo) {
        self.terminalInfo = nil

        DispatchQueue.main.async { [unowned self] in
            self.connectionDelegate?.onDisconnected(terminalInfo: terminalInfo)
        }
    }

    public func configuringTerminal(state: TransactionState) {
        DispatchQueue.main.async { [unowned self] in
            self.connectionDelegate?.configuringTerminal(state: state)
        }
    }
    
    public func onError(error: ConnectionError) {
        DispatchQueue.main.async { [unowned self] in
            self.connectionDelegate?.onError(error: error)
        }
    }
}

extension GMSManager: TransactionDelegate {
    
    public func onDeletedTransactionsComplete(deletedTransactions: [ProcessSaF]) {
        DispatchQueue.main.async { [unowned self] in
            self.transactionDelegate?.onDeletedTransactionsComplete(deletedTransactions: deletedTransactions)
        }
    }
    
    public func onListSaFComplete(transactions: [Transaction]) {
        self.transactionManager = nil
        
        DispatchQueue.main.async { [unowned self] in
            self.transactionDelegate?.onListSaFComplete(transactions: transactions)
        }
    }
    
    public func onState(state: TransactionState) {
        
        DispatchQueue.main.async { [unowned self] in
            self.transactionState = state
            switch self.transactionState {
                case .cancelled:
                    self.transactionManager = nil
                default: break
            }
            self.transactionDelegate?.onState(state: state)
        }
    }
    
    public func requestAIDSelection(aids: [AID]) {
        DispatchQueue.main.async { [unowned self] in
            self.transactionDelegate?.requestAIDSelection(aids: aids)
        }
    }
    
    public func requestAmountConfirmation(amount: Decimal?) {
        DispatchQueue.main.async { [unowned self] in
            self.transactionDelegate?.requestAmountConfirmation(amount: amount)
        }
    }
    
    public func requestSaFApproval() {
        DispatchQueue.main.async { [unowned self] in
            self.transactionDelegate?.requestSaFApproval()
        }
    }

    public func requestPostalCode(maskedPan: String,
                                  expiryDate: String,
                                  cardholderName: String?) {
        DispatchQueue.main.async { [unowned self] in
            self.transactionDelegate?.requestPostalCode(maskedPan: maskedPan,
                                                        expiryDate: expiryDate,
                                                        cardholderName: cardholderName)
        }
    }
    
    public func onTransactionComplete(result: TransactionResult, response: TransactionResponse?) {
        self.transactionManager = nil
        DispatchQueue.main.async { [unowned self] in
            self.transactionDelegate?.onTransactionComplete(result: result, response: response)
        }
    }
    
    public func onTransactionCancelled() {
        self.transactionManager = nil
        DispatchQueue.main.async { [unowned self] in
            self.transactionDelegate?.onTransactionCancelled()
        }
    }
    
    public func onError(error: TransactionError) {
       
        switch error {
        case .terminalFailed(_, let errorCode):
            if errorCode != 200 {
                self.transactionManager = nil
            }
        case .safTransactionFailed(_, transactionID: _):
            break
        default:
            self.transactionManager = nil
        }

        DispatchQueue.main.async { [unowned self] in
            self.transactionDelegate?.onError(error: error)
        }
    }
    
    public func onTransactionWaitingForSurchargeConfirmation(result: TransactionResult, response: TransactionResponse?) {
//        self.transactionManager = nil
        DispatchQueue.main.async { [unowned self] in
            self.transactionDelegate?.onTransactionWaitingForSurchargeConfirmation(result: result, response: response)
        }
    }
    
}

extension GMSManager: TerminalSettingsUpdateDelegate {
    public func onReturnUpdateSetting(settingType: TerminalSettingType, result: TerminalSettingResult) {
        DispatchQueue.main.async { [unowned self] in
            self.terminalSettingsDelegate?.onReturnUpdateSetting(settingType: settingType, result: result)
        }
    }
    
    public func onReturnReadSetting(settingType: TerminalSettingType, value: Int?, error: Error?) {
        DispatchQueue.main.async { [unowned self] in
            self.terminalSettingsDelegate?.onReturnReadSetting(settingType: settingType, value: value, error: error)
        }
    }
}

extension GMSManager: TerminalOTAManagerDelegate {
    public func terminalVersionDetails(info: [AnyHashable : Any]?) {
        DispatchQueue.main.async { [unowned self] in
            self.terminalOTADelegate?.terminalVersionDetails(info: info)
        }
    }
    
    public func terminalOTAResult(resultType: TerminalOTAResult, info: [String : AnyObject]?, error: Error?) {
        DispatchQueue.main.async { [unowned self] in
            self.terminalOTADelegate?.terminalOTAResult(resultType: resultType, info: info, error: error)
        }
    }
    
    public func listOfVersionsFor(type: TerminalOTAUpdateType, results: [Any]?) {
        DispatchQueue.main.async { [unowned self] in
            self.terminalOTADelegate?.listOfVersionsFor(type: type, results: results)
        }
    }
    
    public func onReturnSetTargetVersion(resultType: TerminalOTAResult, type: TerminalOTAUpdateType, message: String) {
        DispatchQueue.main.async { [unowned self] in
            self.terminalOTADelegate?.onReturnSetTargetVersion(resultType: resultType, type: type, message: message)
        }
    }
    
    public func otaUpdateProgress(percentage: Float) {
        DispatchQueue.main.async { [unowned self] in
            self.terminalOTADelegate?.otaUpdateProgress(percentage: percentage)
        }
    }
}
