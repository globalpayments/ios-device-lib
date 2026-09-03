//
//  BBPOSTerminal.swift
//  ios-device-lib
//
//  Copyright (c) 2020 GlobalPayments. All rights reserved.
//

import Foundation
import CoreBluetooth
import ExternalAccessory
import AVFoundation
import MediaPlayer

class BBPOSTerminal: NSObject, Terminal {
    
    static let defaultInputData = ["vendorSecret": "bbpos1",
                                   "vendorID": "bbpos1",
                                   "appID": "bbpos2",
                                   "appSecret": "bbpos2"]
    private var transactionFlowStep = TransactionFlowStep.idle
    var searchDelegate: SearchDelegate?
    var terminalType: TerminalType
    var terminalConfig: TerminalConfig
    var entryModes: [EntryMode] = EntryMode.allCases
    var transactionDelegate: TerminalTransactionDelegate?
    var connectionDelegate: ConnectionDelegate?
    var amount: Decimal?
    var transactionType: TransactionType = .Sale
    var waitForCardRemoval = false
    var batchTlvData: String? = nil
    var onlineTlv: String? = nil
    var reversalTlv: String? = nil
    var localSavedTLV: String?
    var tlv: String? {
        if let batch = batchTlvData {
            return batch
        } else if let reversal = reversalTlv {
            return reversal
        } else {
            return onlineTlv
        }
    }
    var connected: Bool {
        guard let terminalInfo = selectedTerminal else {
            return false
        }
        return terminalInfo.connected
    }
    var otaUpdateType: TerminalOTAUpdateType?
    var selectedTerminal: TerminalInfo?
    var terminalOTAState: TerminalOTAState?
    var otaDelegate: TerminalOTAManagerDelegate?
    var terminalSettingsDelegate: TerminalSettingsUpdateDelegate?
    var terminalSettingType: TerminalSettingType?
    var authType: AuthType = .unknown
    
    private var scannedDevices: [UUID: CBPeripheral] = [:]
    private var fallbackReason = GMSFallbackReason.none
    private var isGatewayTimeOutNoReply = false
    private var hostTimeOut = false
    private var wentOnline = false
    private var receivedGatewayResponse = false
    private var reversalRequested = false
    private var terminalTimeOutDecline = false
    private var isSurchargeTimeOut = false
    private var surchargeEligibility: SurchargeEligibility = .U
    
    private var cardFlowType: BBDeviceCheckCardResult?
    private var cardData: [AnyHashable : Any]?
    private var isConnectRequested = false
    private var isVerifyingConnection = false
    private var verificationTimeoutWorkItem: DispatchWorkItem?
    private var pendingConnectedPeripheral: CBPeripheral?
    private var pendingConnectedTerminalInfo: InternalTerminalInfo?

    private var connectingFinishBlock: ((Bool?) -> Void)?
    private let savedDeviceKey = "lastUsedBBPOSDevice"

    required init?(terminal: TerminalType, config: TerminalConfig) {
        terminalType = terminal
        terminalConfig = config
        super.init()
        BBDeviceController.shared()?.delegate = self
        BBDeviceOTAController.shared()?.delegate = self
        BBDeviceOTAController.shared()?.setOTAServerURL(URL.init(string: PorticoConfig.OTA_SERVER_URL))
        BBDeviceOTAController.shared()?.setBBDevice(BBDeviceController.shared())
#if DEBUG
        BBDeviceController.shared()?.isDebugLogEnabled = true
        BBDeviceOTAController.shared()?.isDebugLogEnabled = true
#endif
    }
    
    func search(delegate: SearchDelegate) {
        searchDelegate = delegate
        BBDeviceController.shared()?.startBTScan(nil, scanTimeout: 15)
    }
    
    func cancelSearch() {
        BBDeviceController.shared()?.stopBTScan()
    }
    
    func connect(terminalInfo: TerminalInfo, delegate: ConnectionDelegate) {
        searchDelegate = nil
        connectionDelegate = delegate
        selectedTerminal = terminalInfo
        isConnectRequested = true
        // Connect with the selected peripheral
        guard let peripheral = scannedDevices[terminalInfo.identifier] else {
            BBDeviceController.shared()?.startBTScan([terminalInfo.name], scanTimeout: 15)
            return
        }
        BBDeviceController.shared()?.connectBT(peripheral)
    }
    
    func disconnect() {
        cancelPendingVerification()
        isConnectRequested = false
        BBDeviceController.shared()?.disconnectBT()
    }
    
    func start(amount: Decimal?, transactionType:TransactionType, entryModes: [EntryMode], delegate: TerminalTransactionDelegate) {
        guard transactionFlowStep != .waitingForCardRemoval else {
            delegate.onError(terminalError: .cardNotRemoved)
            return
        }
        guard !entryModes.isEmpty else {
            delegate.onError(terminalError: .invalidEntryModes)
            return
        }
        batchTlvData = nil
        fallbackReason = .none
        isGatewayTimeOutNoReply = false
        hostTimeOut = false
        wentOnline = false
        reversalRequested = false
        receivedGatewayResponse = false
        terminalTimeOutDecline = false
        transactionDelegate = delegate
        self.amount = amount
        self.transactionType = transactionType
        self.entryModes = entryModes
        transactionFlowStep = .waitingForCard
        
        if (self.cardFlowType != nil) {
            self.cardFlowType = nil
        }
    
        BBDeviceController.shared()?.startEmv(withData: transactionConfig(for: transactionType, entryModes: entryModes))
    }
    
    func confirm(amount: Decimal) {
        BBDeviceController.shared()?.sendFinalConfirmResult(true)
    }
    
    func confirmSurcharge(amount: Decimal) {
        if let cardFlowType = self.cardFlowType, case .swipedCard = cardFlowType {
            guard let data = cardData as? [String: String],
                    let card: AnyCardData = createCardData(tlv: "", data: data) else {

                transactionDelegate?.onError(terminalError: .commandFailed)
                fatalError(" Doesn't have CARD DATA")
            }
           
            transactionDelegate?.requestOnlineProcessing(cardData: card, isSurcharge: true)
        } else {
            guard let tlv = self.localSavedTLV else {
                transactionDelegate?.onError(terminalError: .commandFailed)
                fatalError(" Doesn't have TVL data")
            }
            self.amount = amount
            transactionFlowStep = .onlineProcesssing
            onRequestOnlineProcessBySurchargeConfirmation(tlv)
        }
    }

    func select(aid: AID) {
        BBDeviceController.shared()?.selectApplication(Int32(aid.index ?? 0))
    }
    
    func sendOnlineProcessingResult(response: HostProcessingResult) {
        receivedGatewayResponse = true
        
        if response.transactionState == .gatewayTimeOutNoReply {
            isGatewayTimeOutNoReply = true
        }
        
        if response.transactionState == .hostTimeout {
            hostTimeOut = true
        }
        
        // Sometimes terminal timeouts after requesting Online process, resulting in transaction decline.
        // When Gateway returns No Reply(91), perform the reversal to that transaction.
        if terminalTimeOutDecline {
            if isGatewayTimeOutNoReply && !reversalRequested {
                reversalRequested = true
                transactionDelegate?.requestReversal(tlv: tlv)
                transactionDelegate?.onICCTransactionComplete(result: .timeout, tlv: tlv)
            } else if isGatewayTimeOutNoReply && reversalTlv != nil {
                transactionDelegate?.onICCTransactionComplete(result: .timeout, tlv: reversalTlv)
            } else {
                if hostTimeOut {
                    return
                }
                
                // Gateway Response not received.
                if let _ = reversalTlv {
                    // Terminal Timeout, Terminal requested for reversal, Perform reversal only for Standard EMV
                    if entryModes.contains(.contact) && !entryModes.contains(.quickChip) {
                        transactionDelegate?.onICCTransactionComplete(result: .declined, tlv: reversalTlv)
                        
                        return
                    }
                }
                
                // Remaining cases send Gateway Approval/Decline to POS device.
                transactionDelegate?.onICCTransactionComplete(result: response.transactionState == .onlineApproved ? .success : .declined,
                                                              tlv: tlv)
            }
            
            return
        }
        
        transactionFlowStep = .finishing
        var tlv = ""
        if let emvIssuer = response.emvIssuerAuthenticationData {
            tlv += emvIssuer
        }
        if let issuerAuthCode = response.emvIssuerAuthCode {
            tlv += issuerAuthCode
        }
        if let scripts = response.emvIssuerScripts {
            tlv += scripts
        }
        BBDeviceController.shared()?.sendOnlineProcessResult(tlv)
    }
    
    func cancelTransaction() {
        if let device = BBDeviceController.shared() {
            switch transactionFlowStep {
            case .idle:
                break
            case .waitingForAmount:
                device.cancelSetAmount()
            case .startEmv:
                device.cancelCheckCard()
            case .setAmount:
                device.cancelSetAmount()
            case .confirmAmount:
                device.sendFinalConfirmResult(false)
            case .selectAid:
                device.cancelSelectApplication()
            case .onlineProcesssing:
                device.sendOnlineProcessResult(device.encodeTlv(["8A":""]))
            case .finishing:
                break
            case .waitingForNfc:
                device.stopNfcDetection(["nfcCardRemovalTimeout": 0])
            case .waitingForCard, .waitingForCardRemoval:
                device.cancelCheckCard()
            case .waitingForSurchargeConfirmation:
                device.cancelCheckCard()
            }
        }
    }
    
    func releaseDevice() {
        if let device = BBDeviceController.shared() {
            device.release()
        }
    }
    
    func terminalVersionData(delegate: TerminalOTAManagerDelegate) {
        otaDelegate = delegate
        BBDeviceController.shared()?.getDeviceInfo()
    }
    
    func readTerminalSetting(settingType: TerminalSettingType, delegate: TerminalSettingsUpdateDelegate) {
        terminalSettingsDelegate = delegate
        terminalSettingType = settingType
        let dol: String
        switch settingType {
        case .normalModeTimeout:
            dol = Utilities.hexString(fromEMVTagEnum: EMVTagDescriptor.bbposNormalModeTimeout)
        case .bluetoothDiscoveryTimeout:
            dol = Utilities.hexString(fromEMVTagEnum: EMVTagDescriptor.bbposBluetoothDiscoveryTimeout)
        case .standByModeTimeout:
            dol = Utilities.hexString(fromEMVTagEnum: EMVTagDescriptor.bbposStandbyModeTimeout)
        }
        
        BBDeviceController.shared().readTerminalSetting(dol)
    }
    
    func updateTerminalSetting(settingType: TerminalSettingType, dol: String, delegate: TerminalSettingsUpdateDelegate) {
        terminalSettingsDelegate = delegate
        terminalSettingType = settingType
        let dolKey: String
        var dolValue = dol
        
        switch settingType {
        case .normalModeTimeout:
            dolKey = Utilities.hexString(fromEMVTagEnum: EMVTagDescriptor.bbposNormalModeTimeout)
        case .bluetoothDiscoveryTimeout:
            dolKey = Utilities.hexString(fromEMVTagEnum: EMVTagDescriptor.bbposBluetoothDiscoveryTimeout)
        case .standByModeTimeout:
            dolKey = Utilities.hexString(fromEMVTagEnum: EMVTagDescriptor.bbposStandbyModeTimeout)
        }
        
        if dolValue.count == 1 { // Adding 0 perfix to handle single hex value dol
            dolValue = "0" + dolValue
        }
        
        if let tlv = BBDeviceController.shared()?.encodeTlv([dolKey: dolValue]), !tlv.isEmpty {
            BBDeviceController.shared()?.updateTerminalSetting(tlv)
        } else {
            terminalSettingsDelegate?.onReturnUpdateSetting(settingType: settingType, result: .invalidTlvFormat)
        }
    }
    
    func listAvailableOTAVersionsFor(type: TerminalOTAUpdateType, delegate: TerminalOTAManagerDelegate) {
        otaDelegate = delegate
        otaUpdateType = type
        
        var inputData: [AnyHashable: Any] = BBPOSTerminal.defaultInputData
        inputData["listType"] = type.rawValue
        BBDeviceOTAController.shared()?.getTargetVersionList(withData: inputData)
    }
    
    func setTerminalVersionsFor(type: TerminalOTAUpdateType, versionString: String, delegate: TerminalOTAManagerDelegate) {
        otaDelegate = delegate
        otaUpdateType = type
        
        var inputData: [AnyHashable: Any] = BBPOSTerminal.defaultInputData
        inputData["listType"] = type.rawValue
        inputData["applyToAll"] = false
        
        switch type {
        case .firmware:
            inputData["firmwareVersion"] = versionString
        case .config:
            inputData["deviceSettingVersion"] = versionString
            inputData["terminalSettingVersion"] = versionString
        case .keyInjection:
            break
        }
        
        BBDeviceOTAController.shared()?.setTargetVersionWithData(inputData)
        
    }
    
    func startOTAUpdateProcess(type: TerminalOTAUpdateType, selectedVersion: String, delegate: TerminalOTAManagerDelegate) {
        otaDelegate = delegate
        otaUpdateType = type
        
        var inputData: [AnyHashable: Any] = BBPOSTerminal.defaultInputData
        inputData["forceUpdate"] = true
        
        switch type {
        case .firmware:
            inputData["firmwareType"] = BBDeviceFirmwareType.mainProcessor
            BBDeviceOTAController.shared()?.startRemoteFirmwareUpdate(withData: inputData)
        case .config:
            inputData["configType"] = BBDeviceConfigType.firmwareConfig.rawValue
            BBDeviceOTAController.shared()?.startRemoteConfigUpdate(withData: inputData)
        case .keyInjection:
            BBDeviceOTAController.shared()?.startRemoteKeyInjection(withData: inputData)
        }
    }

    func hasSavedDevice() -> Bool {
        return loadLastDevice() != nil
    }

    func reconnectLastDevice(connectingFinishBlock: @escaping (Bool?) -> Void) {
        guard let saved = loadLastDevice() else {
            connectingFinishBlock(false)
            return
        }
        let uuid = UUID(uuidString: saved.identifier) ?? UUID()
        selectedTerminal = GMSTerminalInfo(name: saved.name,
                                           description: saved.name,
                                           connected: false,
                                           terminalType: terminalType,
                                           identifier: uuid)

        isConnectRequested = true
        self.connectingFinishBlock = connectingFinishBlock

        if let peripheral = scannedDevices[uuid] {
            BBDeviceController.shared()?.connectBT(peripheral)
        } else {
            BBDeviceController.shared()?.startBTScan(nil, scanTimeout: 15)
        }
    }
}

extension BBPOSTerminal: BBDeviceControllerDelegate {
    
    /// **Search callbacks**
    func onBTReturnScanResults(_ devices: [Any]!) {
        devices.forEach {
            guard let peripheral = $0 as? CBPeripheral, scannedDevices[peripheral.identifier] == nil else {
                return
            }
            let terminalInfo = GMSTerminalInfo(name: peripheral.name ?? "",
                                               description: peripheral.description,
                                               connected: false,
                                               terminalType: terminalType,
                                               identifier: peripheral.identifier)
            scannedDevices[peripheral.identifier] = peripheral
            if isConnectRequested, peripheral.identifier == selectedTerminal?.identifier {
                BBDeviceController.shared()?.connectBT(peripheral)
            }
            searchDelegate?.deviceFound(terminalInfo: terminalInfo)
        }
    }
    
    func onBTScanStopped() {
        searchDelegate?.onSearchComplete()
    }
    
    func onBTScanTimeout() {
        connectingFinishBlock?(false)
        connectingFinishBlock = nil
        searchDelegate?.onSearchComplete()
    }
    
    /// **Connction callbacks**
    func onBTConnected(_ connectedDevice: NSObject!) {
        guard isConnectRequested else {
            return
        }
        guard let terminalInfo = selectedTerminal as? InternalTerminalInfo,
              let peripheral = connectedDevice as? CBPeripheral else {
            return
        }
        // The BT link may be established while the reader is still in pairing
        // mode and not genuinely responsive. Verify the connection before
        // reporting it to avoid a false positive onConnected.
        verifyConnectionOrTeardown(peripheral: peripheral, terminalInfo: terminalInfo)
    }
    
    func onBTDisconnected() {
        cancelPendingVerification()
        isConnectRequested = false
        guard var terminalInfo = selectedTerminal as? InternalTerminalInfo else {
            return
        }
        terminalInfo.setConnected(false)
        selectedTerminal = terminalInfo
        connectingFinishBlock?(false)
        connectingFinishBlock = nil
        connectionDelegate?.onDisconnected(terminalInfo: terminalInfo)
        clearLastDevice()
    }
    
    func onBTConnectTimeout() {
        cancelPendingVerification()
        isConnectRequested = false
        connectingFinishBlock?(false)
        connectingFinishBlock = nil
        connectionDelegate?.onError(error: .bluetoothConnectionTimeout)
    }
    
    func onDeviceHere(_ isHere: Bool) {
        guard isVerifyingConnection else {
            return
        }
        let peripheral = pendingConnectedPeripheral
        let terminalInfo = pendingConnectedTerminalInfo
        cancelPendingVerification()
        if isHere, let terminalInfo = terminalInfo {
            // The reader genuinely responded — the connection is real.
            var terminalInfo = terminalInfo
            terminalInfo.setConnected(true)
            if let peripheral = peripheral {
                terminalInfo.identifier = peripheral.identifier
                scannedDevices[peripheral.identifier] = peripheral
                saveLastDevice(peripheral: peripheral)
            }
            selectedTerminal = terminalInfo
            connectingFinishBlock?(true)
            connectingFinishBlock = nil
            connectionDelegate?.onConnected(terminalInfo: terminalInfo)
        } else {
            teardownStaleConnection()
        }
    }

    func onReturnReadTerminalSettingResult(_ data: [AnyHashable : Any]!) {
        var terminalSettingKey: String = ""
        if data.count ==  1 {
            switch terminalSettingType {
            case .normalModeTimeout:
                terminalSettingKey =  Utilities.hexString(fromEMVTagEnum: EMVTagDescriptor.bbposNormalModeTimeout)
            case .bluetoothDiscoveryTimeout:
                terminalSettingKey =  Utilities.hexString(fromEMVTagEnum: EMVTagDescriptor.bbposBluetoothDiscoveryTimeout)
            case .standByModeTimeout:
                terminalSettingKey =  Utilities.hexString(fromEMVTagEnum: EMVTagDescriptor.bbposStandbyModeTimeout)
            case .none:
                terminalSettingKey = ""
            }
        }
        if let value = data[terminalSettingKey] as? String,
           let intValue = Int(value, radix: 16) {
            terminalSettingsDelegate?.onReturnReadSetting(settingType: terminalSettingType ?? .normalModeTimeout, value: intValue, error: nil)
        } else {
            terminalSettingsDelegate?.onReturnReadSetting(settingType: terminalSettingType ?? .normalModeTimeout, value: nil, error: GatewayError.badRequest(message: "Couldn't able to read terminal settings"))
        }
    }
    
    func onReturnUpdateTerminalSettingResult(status: BBDeviceTerminalSettingStatus) {
        terminalSettingsDelegate?.onReturnUpdateSetting(settingType: terminalSettingType ?? .normalModeTimeout, result: TerminalSettingResult(rawValue: status.rawValue) ?? .invalidValue)
    }
}

extension BBPOSTerminal {

    private func verifyConnectionOrTeardown(peripheral: CBPeripheral?, terminalInfo: InternalTerminalInfo) {
        guard isConnectRequested else {
            // No connection was requested — just clear the stale state silently.
            BBDeviceController.shared()?.disconnectBT()
            return
        }
        guard !isVerifyingConnection else {
            return
        }
        isVerifyingConnection = true
        pendingConnectedPeripheral = peripheral
        pendingConnectedTerminalInfo = terminalInfo
        // Send a detect command to check whether the reader genuinely responds.
        BBDeviceController.shared()?.isDeviceHere()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self, self.isVerifyingConnection else {
                return
            }
            // No response — the reader is not truly connected. Tear down the
            // stale state so a subsequent connect can succeed.
            self.teardownStaleConnection()
        }
        verificationTimeoutWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: workItem)
    }

    private func cancelPendingVerification() {
        verificationTimeoutWorkItem?.cancel()
        verificationTimeoutWorkItem = nil
        isVerifyingConnection = false
        pendingConnectedPeripheral = nil
        pendingConnectedTerminalInfo = nil
    }

    private func teardownStaleConnection() {
        cancelPendingVerification()
        isConnectRequested = false
        connectingFinishBlock?(false)
        connectingFinishBlock = nil
        connectionDelegate?.onError(error: .bluetoothConnectionLost)
        BBDeviceController.shared()?.disconnectBT()
    }
}

extension BBPOSTerminal {
    
    func onRequestSetAmount() {
        transactionFlowStep = .waitingForAmount
        let inputData: [String : Any]
        guard let amount = amount else {
            inputData = ["amount": "0",
                         "cashbackAmount": "0",
                         "currencyCode": "840",
                         "transactionType": getBBTransactionType(transactionType: transactionType).rawValue,
                         "currencyCharacters": []] as [String : Any]
            BBDeviceController.shared()?.setAmount(inputData)
            return
        }
        inputData = ["amount": "\(amount)",
                     "cashbackAmount": "0",
                     "currencyCode": "840",
                     "transactionType": getBBTransactionType(transactionType: transactionType).rawValue,
                     "currencyCharacters": []] as [String : Any]
        BBDeviceController.shared()?.setAmount(inputData)
    }
    
    func onWaiting(forCard checkCardMode: BBDeviceCheckCardMode) {
        transactionFlowStep = .waitingForCard
    }
    
    func onReturnCancelCheckCardResult(_ isSuccess: Bool) {
        transactionDelegate?.onICCTransactionCancelled()
    }
    
    func onReturnEmvCardDataResult(_ applicationArray: [Any]!) {
        print("onReturnEmvCardDataResult - applicationArray: \(applicationArray)")
    }
    
    func onReturnEmvCardDataResult(_ isSuccess: Bool, tlv: String!) {
        
        let data = BBDeviceController.shared()?.decodeTlv(tlv)
        guard let fields = data as? [String: String],
              let cardData: AnyCardData = createCardData(tlv: tlv, data: fields) else {
            transactionDelegate?.onError(terminalError: .commandFailed)
            
            fatalError(" Doesn't have a card data ")
        }
    }
    
    
    func onReturnCheckCardResult(result: BBDeviceCheckCardResult, cardData: [AnyHashable : Any]!) {
       
        self.cardFlowType = result
        self.cardData = cardData
        
        switch result {
        case .noCard:
            transactionFlowStep = .idle
            transactionDelegate?.onState(state: .cardRemoved)
        case .swipedCard:
            
            guard let data = cardData as? [String: String], let card: AnyCardData = createCardData(tlv: "", data: data) else {
                transactionDelegate?.onError(terminalError: .commandFailed)
                return
            }
            
            // IF THE BUILDER SAYS isSurchargeEnabled we continue, if not, we will do the sale either way.

            guard let isSurchargeEnabled = transactionDelegate?.isSurchargeEnabled(), isSurchargeEnabled else {
                
                self.isSurchargeTimeOut = true
                self.transactionDelegate?.setSurchargeTimeOutError(isSurchargeTimeOutError: self.isSurchargeTimeOut, surchargeElibigility: .U, completion: {
                    
                    self.transactionDelegate?.requestOnlineProcessing(cardData: card, isSurcharge: false)
                })
                
                return
            }
           
            transactionDelegate?.requestOnlineBinCheck(cardData: card, completion: { response, error in
                
                if let error {
                    
                    self.isSurchargeTimeOut = true
                    self.transactionDelegate?.setSurchargeTimeOutError(isSurchargeTimeOutError: self.isSurchargeTimeOut, surchargeElibigility: .U, completion: {
                        
                        self.transactionDelegate?.requestOnlineProcessing(cardData: card, isSurcharge: false)
                    })
                    return
                }
                
                if let response = response,
                   let surchargeRequired = response.surchargeRequested, case .Y = surchargeRequired {
                    
                    self.isSurchargeTimeOut = false
                    self.transactionDelegate?.setSurchargeTimeOutError(isSurchargeTimeOutError: self.isSurchargeTimeOut, surchargeElibigility: .Y, completion: {
                        self.transactionDelegate?.onState(state: .waitingForSurchargeAcceptance)
                        
                        self.transactionDelegate?.onTransactionWaitingForSurchargeConfirmation(result: .surchargeRequested,
                                                                                               response: response)
                    })
                    
                } else {
                    
                    self.transactionDelegate?.setSurchargeTimeOutError(isSurchargeTimeOutError: self.isSurchargeTimeOut, surchargeElibigility: .N, completion: {
                        
                        self.transactionDelegate?.requestOnlineProcessing(cardData: card, isSurcharge: false)
                    })
                   
                }
            })
//            transactionDelegate?.requestOnlineProcessing(cardData: card)
        case .insertedCard:
            if let data = cardData as? [String: String], let card: AnyCardData = createCardData(tlv: "", data: data) {
                
            }
            transactionFlowStep = .waitingForCardRemoval
            transactionDelegate?.onState(state: .cardDetected)
            
        case .useIccCard:
            transactionFlowStep = .waitingForCard
            transactionDelegate?.onState(state: .insertCard)
            
        default:
#if DEBUG
            fatalError("unexpected callback checkCardResult:\(result) data:\(cardData.description)")
#endif
            break
        }
    }
    
    func isSurchargeEnabled() -> Bool {
        fatalError("Needs implementation")
    }
    
    func setSurchargeTimeOutError(isSurchargeTimeOutError: Bool, completion: @escaping (() -> Void)) {
        self.isSurchargeTimeOut = isSurchargeTimeOutError
        completion()
    }
    
    func onRequestSelectApplication(_ applicationArray: [Any]) {
        transactionFlowStep = .selectAid
        
        var aids = [AID]()
        for (index, item) in applicationArray.enumerated() {
            if let string = item as? String,
               let values = BBDeviceController.shared().decodeTlv(string) {
                let rid: String? = values[""] as? String
                let pix: String? = values[""] as? String
                let applicationIdentifier: String = values["4F"] as? String ?? ""
                let label: String? = values["50"] as? String
                
                // Application Pref Name doesn't support Issuer Table Code `05` as it produces cyclic characters
                var preferredName: String?
                if let issuerTableCode = values["9F11"] as? String, issuerTableCode == "05" {
                    preferredName = label
                } else {
                    preferredName = values["9F07"] as? String ?? values["9F12"] as? String
                }
                
                aids.append(AID(rid: rid,
                                pix: pix,
                                applicationIdentifier: applicationIdentifier,
                                tlv: string,
                                index: index,
                                label: TLVUtility.hexToAscii(label),
                                preferredName: TLVUtility.hexToAscii(preferredName)))
            }
        }
        transactionDelegate?.requestAIDSelection(aids: aids)
    }
    
    func onRequestFinalConfirm() {
        transactionFlowStep = .confirmAmount
        transactionDelegate?.requestAmountConfirmation(amount: amount)
    }
    
    func onRequestOnlineProcess(_ tlv: String) {
       
        // MARK: Saving TLV locally
        self.localSavedTLV = tlv
        
        switch transactionType {
        case .Auth, .Sale:
            let data = BBDeviceController.shared()?.decodeTlv(tlv)
            guard let fields = data as? [String: String],
                  let cardData: AnyCardData = createCardData(tlv: tlv, data: fields) else {
                transactionDelegate?.onError(terminalError: .commandFailed)
                
                fatalError(" Doesn't have a card data ")
            }
            
            // IF THE BUILDER SAYS isSurchargeEnabled we continue, if not, we will do the sale either way.

            guard let isSurchargeEnabled = transactionDelegate?.isSurchargeEnabled(), isSurchargeEnabled else {
                
                
                self.transactionFlowStep = .onlineProcesssing
                let data = BBDeviceController.shared()?.decodeTlv(tlv)
                guard let fields = data as? [String: String],
                      let cardData: AnyCardData = self.createCardData(tlv: tlv, data: fields) else {
                    BBDeviceController.shared()?.sendOnlineProcessResult("")
                    return
                }

                self.wentOnline = true
               
                self.transactionDelegate?.requestOnlineProcessing(cardData: cardData, isSurcharge: false)
                
                
                return
            }
            
            // Will call a dispatch queue for calling the checkBinCard API and on the block code it will check for the true verification, if needed, call onTransactionWaitingForSurchargeConfirmation, if not, call requestOnlineProcessing
            
            transactionDelegate?.requestOnlineBinCheck(cardData: cardData, completion: { response, error in
                
                if let error {
                    
                    self.isSurchargeTimeOut = true
                    self.transactionDelegate?.setSurchargeTimeOutError(isSurchargeTimeOutError: self.isSurchargeTimeOut, surchargeElibigility: .U, completion: {
                        
                        self.transactionDelegate?.requestOnlineProcessing(cardData: cardData, isSurcharge: false)
                        
                    })
                    return
                }
             
                if let response = response,
                    let surchargeRequired = response.surchargeRequested,
                    case .Y = surchargeRequired {
                    self.transactionDelegate?.setSurchargeTimeOutError(isSurchargeTimeOutError: self.isSurchargeTimeOut, surchargeElibigility: .Y, completion: {
                        
                        self.transactionFlowStep = .waitingForSurchargeConfirmation
                        self.transactionDelegate?.onState(state: .waitingForSurchargeAcceptance)
                        self.transactionDelegate?.onTransactionWaitingForSurchargeConfirmation(result: .surchargeRequested,
                                                                                               response: response)
                    })
                    
                } else {
                    self.transactionDelegate?.setSurchargeTimeOutError(isSurchargeTimeOutError: self.isSurchargeTimeOut, surchargeElibigility: .N, completion: {
                        
                        let data = BBDeviceController.shared()?.decodeTlv(tlv)
                        if let fields = data as? [String: String],
                              var cardData: AnyCardData = self.createCardData(tlv: tlv,
                                                                              data: fields) {
                            
                            cardData.cardData = cardData
                        }
                        self.transactionDelegate?.requestOnlineProcessing(cardData: cardData, isSurcharge: false)
                    })
                }
            })
           
        default:
            transactionFlowStep = .onlineProcesssing
            let data = BBDeviceController.shared()?.decodeTlv(tlv)
            guard let fields = data as? [String: String],
                  let cardData: AnyCardData = createCardData(tlv: tlv, data: fields) else {
                BBDeviceController.shared()?.sendOnlineProcessResult("")
                return
            }

            wentOnline = true
            
            transactionDelegate?.requestOnlineProcessing(cardData: cardData, isSurcharge: false)
        }
    }
    
    func onRequestOnlineProcessBySurchargeConfirmation(_ tlv: String) {
        transactionFlowStep = .onlineProcesssing
        let data = BBDeviceController.shared()?.decodeTlv(tlv)
        guard let fields = data as? [String: String],
              let cardData: AnyCardData = createCardData(tlv: tlv, data: fields) else {
            BBDeviceController.shared()?.sendOnlineProcessResult("")
            return
        }
        
        wentOnline = true
        
        transactionDelegate?.requestOnlineProcessing(cardData: cardData, isSurcharge: true)
    }
    
    func onReturnBatchData(_ tlv: String) {
        batchTlvData = tlv
    }
    
    func onReturnReversalData(_ tlv: String) {
        reversalTlv = tlv
        reversalRequested = true
        transactionDelegate?.requestReversal(tlv: tlv)
    }
    
    func onReturnTransactionResult(result: BBDeviceTransactionResult) {
        switch result {
        case .approved:
            transactionDelegate?.onICCTransactionComplete(result: .approved, tlv: onlineTlv)
        case .terminated:
            transactionDelegate?.onICCTransactionComplete(result: .terminated, tlv: tlv)
        case .declined:
            terminalTimeOutDecline = true
            if !wentOnline {
                // Terminal declined transaction offline, here reversal not required.
                // This should be common for Propay and Portico.
                transactionDelegate?.onICCTransactionComplete(result: .offlineDecline, tlv: tlv)
            } else {
                // If Gateway Response is not received then wait for it, it'll be handled when gateway response is received.
                if receivedGatewayResponse {
                    if hostTimeOut {
                        return
                    }
                    
                    if isGatewayTimeOutNoReply {
                        // Received Portico No Reply response (GatewayCode 91), reversal needs to be performed
                        if !reversalRequested {
                            reversalRequested = true
                            transactionDelegate?.requestReversal(tlv: tlv)
                        }
                        
                        transactionDelegate?.onICCTransactionComplete(result: .declined, tlv: tlv)
                    } else {
                        if let reversalData = reversalTlv {
                            // Received Gateway Response, Terminal requested for reversal before declining transaction
                            // Perform reversal only for Standard EMV
                            if let data = BBDeviceController.shared()?.decodeTlv(reversalData),
                               let quickChipIndicator = data[BBDeviceConstants.quickChipIndicator] as? String,
                               quickChipIndicator == BBDeviceConstants.quickChipIndicatorDisabled {
                                transactionDelegate?.onICCTransactionComplete(result: .postAuthChipDecline, tlv: reversalTlv)
                                
                                return
                            }
                        }
                        
                        transactionDelegate?.onICCTransactionComplete(result: .declined, tlv: tlv)
                    }
                }
            }
        case .canceled:
            transactionDelegate?.onICCTransactionComplete(result: .canceled, tlv: tlv)
        case .timeout:
            transactionDelegate?.onICCTransactionComplete(result: .timeout, tlv: tlv)
        case .capkFail:
            transactionDelegate?.onICCTransactionComplete(result: .capkFail, tlv: tlv)
        case .notIcc:
            transactionDelegate?.onICCTransactionComplete(result: .notIcc, tlv: tlv)
        case .cardBlocked:
            transactionDelegate?.onICCTransactionComplete(result: .cardBlocked, tlv: tlv)
        case .deviceError:
            transactionDelegate?.onICCTransactionComplete(result: .deviceError, tlv: tlv)
        case .noEmvApps:
            transactionDelegate?.onICCTransactionComplete(result: .noEmvApps, tlv: tlv)
        case .iccCardRemoved:
            transactionDelegate?.onICCTransactionComplete(result: .iccCardRemoved, tlv: tlv)
        case .cardSchemeNotMatched:
            transactionDelegate?.onICCTransactionComplete(result: .cardSchemeNotMatched, tlv: tlv)
        default:
            transactionDelegate?.onICCTransactionComplete(result: .terminated, tlv: tlv)
        }
    }
    
    func onRequestDisplayText(displayText: BBDeviceDisplayText, displayTextLanguage languageCode: String!) {
        var cardReadState: TransactionState?
        
        switch displayText {
        case .APPROVED:
            print("APPROVED")
            return
        case .CALL_YOUR_BANK:
            print("CALL_YOUR_BANK")
            return
        case .DECLINED:
            print("DECLINED")
            cardReadState = .terminalDeclined
        case .ENTER_AMOUNT:
            print("ENTER_AMOUNT")
            return
        case .ENTER_PIN:
            print("ENTER_PIN")
            return
        case .INCORRECT_PIN:
            print("INCORRECT_PIN")
            return
        case .INSERT_CARD:
            print("INSERT_CARD")
            cardReadState = .insertCard
        case .NOT_ACCEPTED:
            print("NOT_ACCEPTED")
            return
        case .PIN_OK:
            print("PIN_OK")
            return
        case .PLEASE_WAIT:
            print("PLEASE_WAIT")
            cardReadState = .pleaseWait
        case .REMOVE_CARD:
            print("REMOVE_CARD")
            cardReadState = .removeCard
        case .USE_MAG_STRIPE:
            cardReadState = .useMagstripe
        case .TRY_AGAIN:
            print("TRY_AGAIN")
            cardReadState = .tryAgain
        case .REFER_TO_YOUR_PAYMENT_DEVICE:
            print("REFER_TO_YOUR_PAYMENT_DEVICE")
            cardReadState = .pleaseSeePhone
        case .TRANSACTION_TERMINATED:
            print("TRANSACTION_TERMINATED")
            cardReadState = .transactionTerminated
        case .PROCESSING:
            print("PROCESSING")
            cardReadState = .processing
        case .LAST_PIN_TRY:
            print("LAST_PIN_TRY")
            return
        case .SELECT_ACCOUNT:
            print("SELECT_ACCOUNT")
            return
        case .PRESENT_CARD:
            print("PRESENT_CARD")
            if transactionFlowStep == .waitingForCard {
                return
            }
            transactionFlowStep = .waitingForCard
            cardReadState = .presentCard
            cardReadState = fallbackReason != .none ? .useMagstripe : cardReadState
        case .APPROVED_PLEASE_SIGN:
            print("APPROVED_PLEASE_SIGN")
            return
        case .PRESENT_CARD_AGAIN:
            print("PRESENT_CARD_AGAIN")
            transactionFlowStep = .waitingForCard
            cardReadState = .presentCardAgain
        case .AUTHORISING:
            print("AUTHORISING")
            cardReadState = .pleaseWait
        case .INSERT_SWIPE_OR_TRY_ANOTHER_CARD:
            print("INSERT_SWIPE_OR_TRY_ANOTHER_CARD")
            transactionFlowStep = .waitingForCard
            cardReadState = .insertSwipeOrTryAnotherCard
        case .INSERT_OR_SWIPE_CARD:
            print("INSERT_OR_SWIPE_CARD")
            transactionFlowStep = .waitingForCard
            cardReadState = .insertOrSwipeCard
        case .MULTIPLE_CARDS_DETECTED:
            print("MULTIPLE_CARDS_DETECTED")
            cardReadState = .multipleCardDetected
        case .TIMEOUT:
            print("TIMEOUT")
            return
        case .APPLICATION_EXPIRED:
            print("APPLICATION_EXPIRED")
            fallbackReason = .iccError
            cardReadState = .applicationExpired
        case .FINAL_CONFIRM:
            print("FINAL_CONFIRM")
            return
        case .SHOW_THANK_YOU:
            print("SHOW_THANK_YOU")
            return
        case .PIN_TRY_LIMIT_EXCEEDED:
            print("PIN_TRY_LIMIT_EXCEEDED")
            return
        case .NOT_ICC_CARD:
            print("NOT_ICC_CARD")
            cardReadState = .cardReadError
        case .CARD_INSERTED:
            print("CARD_INSERTED")
            return
        case .CARD_REMOVED:
            print("CARD_REMOVED")
            return
        case .NO_EMV_APPS:
            print("NO_EMV_APPS")
            fallbackReason = .emptyCandidateList
            cardReadState = .noEmvApps
        case .CTL_NO_EMV_APPS:
            print("CTL_NO_EMV_APPS")
            cardReadState = .noEmvApps
            return
        case .CTL_APP_NOT_SUPPORTED:
            print("CTL_APP_NOT_SUPPORTED")
            return
        case .CTL_TRANSACTION_LIMIT_EXCEEDED:
            print("CTL_TRANSACTION_LIMIT_EXCEEDED")
            return
        @unknown default:
            print(" 💁🏻‍♂️ ")
        }
        
        if cardReadState != nil {
            transactionDelegate?.onState(state: cardReadState!)
        }
    }
    
    func onError(errorType: BBDeviceErrorType, errorMessage: String) {
        // TODO: Handle other errors here.
        switch errorType {
        case .btAlreadyConnected:
            guard isConnectRequested else {
                return
            }
            guard let terminalInfo = selectedTerminal as? InternalTerminalInfo else {
                return
            }
            let peripheral = BBDeviceController.shared()?.getConnectedBTDevice() as? CBPeripheral
            verifyConnectionOrTeardown(peripheral: peripheral, terminalInfo: terminalInfo)

        case .pairingError_AlreadyPairedWithAnotherDevice:
            connectionDelegate?.onError(error: .alreadyPairedWithAnotherDevice)
            return
        case .deviceBusy, .illegalStateException:
            if let device = BBDeviceController.shared() {
                device.cancelCheckCard()
                return
            }
            fallthrough
        default:
            print("\(errorType): \(errorMessage)")
            break
        }
    }
}

extension BBPOSTerminal {
    
    func transactionConfig(for type: TransactionType, entryModes: [EntryMode]) -> [String: Any] {
        var config: [String: Any] = [:]
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "YYMMddHHmmss"
        config["terminalTime"] = dateFormatter.string(from: Date())
        config["checkCardMode"] = getCheckCardMode(entryModes: entryModes).rawValue
        config["disableQuickChip"] = !(terminalConfig.entryModes.contains(.quickChip) && entryModes.contains(.quickChip))
        config["transactionType"] = getBBTransactionType(transactionType: type).rawValue
        
        config["onlineProcessTimeout"] = 90 // Setting by default to 90 secs
        if let onlineProcessTimeOut = terminalConfig.terminalOnlineProcessTimeout {
            config["onlineProcessTimeout"] = NSNumber(value: onlineProcessTimeOut)
        }
        
        return config
    }
    
    func getCheckCardMode(entryModes: [EntryMode]) -> BBDeviceCheckCardMode {
        var modes = [EntryMode]()
        entryModes.forEach { mode in
            if terminalConfig.entryModes.contains(mode) {
                modes.append(mode)
            }
        }
        
        if modes.count == 0 {
            modes.append(contentsOf: terminalConfig.entryModes)
        }
        
        if modes.contains(.contact), modes.contains(.contactless), modes.contains(.msr) {
            return .swipeOrInsertOrTap
        }
        
        if modes.contains(.contact), modes.contains(.contactless) {
            return .insertOrTap
        }
        
        if modes.contains(.contactless), modes.contains(.msr) {
            return .swipeOrTap
        }
        
        if modes.contains(.contact), modes.contains(.msr) {
            return .swipeOrInsert
        }
        
        if modes.contains(.contactless) {
            return .tap
        }
        
        if modes.contains(.contact) {
            return .insert
        }
        
        if modes.contains(.msr) {
            return .swipe
        }
        
        return .swipeOrInsertOrTap
    }
    
    func getBBTransactionType(transactionType: TransactionType) -> BBDeviceTransactionType {
        switch transactionType {
        case .Auth, .Sale: return BBDeviceTransactionType.goods
        case .Void: return BBDeviceTransactionType.void
        case .Return: return BBDeviceTransactionType.refund
        case .Tokenize, .Verify: return BBDeviceTransactionType.inquiry
        default:
            fatalError("Invalid terminal transaction type. Card entry not supported for \(transactionType)")
        }
    }
}

extension BBPOSTerminal {
    
    func createCardData(tlv: String, data: [String: String]) -> AnyCardData? {
        guard let entryMode = data[BBDeviceConstants.entryMode] ?? data["posEntryMode"] else { return nil }
        switch entryMode {
        case BBDeviceConstants.entryModeICC:
            
            guard let contactCard: ContactCardData = createCardData(tlv: tlv, data: data) else { return nil }
            return AnyCardData.init(cardData: contactCard)
        case BBDeviceConstants.entryModeManual:
            guard let manualCard: ManualCardData = createCardData(data: data) else { return nil }
            return AnyCardData.init(cardData: manualCard)
        case BBDeviceConstants.entryModeContactlessEMVMode:
            guard let contactlessCard: ContactlessCardData = createCardData(tlv: tlv, data: data) else { return nil }
            return AnyCardData.init(cardData: contactlessCard)
        case BBDeviceConstants.entryModeContactlessMagstripeMode:
            // This mode is not supported, so the Terminal should decline the trasaction gracefully.
            return nil
        case BBDeviceConstants.entryModeFallbacktoMagneticStripe:
            guard let fallbackCard: MSRFallbackCardData = createCardData(data: data) else { return nil }
            return AnyCardData.init(cardData: fallbackCard)
        case BBDeviceConstants.entryModeFullMagneticStripeRead:
            if fallbackReason != .none {
                guard let fallbackCard: MSRFallbackCardData = createCardData(data: data) else { return nil }
                return AnyCardData.init(cardData: fallbackCard)
            }
            
            guard let msrCard: MSRCardData = createCardData(data: data) else { return nil }
            return AnyCardData.init(cardData: msrCard)
        default:
            return nil
        }
    }
    
    func createCardData(tlv: String, data: [String: String]) -> ContactCardData? {
        print(" CREATING CONTACT CARD ")
        print(tlv)
        
        let serviceCode: Int?
        if let serviceCodeData = data["5F30"] {
            serviceCode = Int(serviceCodeData)
        } else {
            serviceCode = nil
        }
       
        var cardData = ContactCardData.cardData(cardholderName: data["5F20"],
                                                encryptedTrack1: data["56"],
                                                encryptedTrack2: data["C8"],
                                                expirationDate: data["5F24"],
                                                formatID: nil,
                                                ksn: data["C7"],
                                                maskedPAN: data["C4"],
                                                serialNumber: data["DF826E"],
                                                serviceCode: serviceCode,
                                                tlvData: tlv,
                                                terminalType: terminalType)
        cardData.aid = data["4F"]
        cardData.applicationLabel = data["50"]
        cardData.tsi = data["9B"]
        cardData.cvm = data["9F34"]
        cardData.tvr = data["95"]
        
        return cardData
    }
    
    func createCardData(tlv: String, data: [String: String]) -> ContactlessCardData? {
        print(" CREATING CONTACT CARD - LESS ")
        print(tlv)
        let serviceCode: Int?
        if let serviceCodeData = data["5F30"] {
            serviceCode = Int(serviceCodeData)
        } else {
            serviceCode = nil
        }
       
        var cardData = ContactlessCardData.cardData(cardholderName: data["5F20"],
                                                    encryptedTrack1: data["56"],
                                                    encryptedTrack2: data["C8"],
                                                    expirationDate: data["5F24"],
                                                    formatID: nil,
                                                    ksn: data["C7"],
                                                    maskedPAN: data["C4"],
                                                    serialNumber: data["DF826E"],
                                                    serviceCode: serviceCode,
                                                    tlvData: tlv,
                                                    terminalType: terminalType)
        
        cardData.aid = data["4F"]
        cardData.applicationLabel = data["50"]
        cardData.tsi = data["9B"]
        cardData.cvm = data["9F34"]
        cardData.tvr = data["95"]
        
        return cardData
    }
    
    func createCardData(data: [String: String]) -> ManualCardData? {
        return nil
    }
    
    func createCardData(data: [String: String]) -> MSRFallbackCardData? {
        let rawFormatID = data["formatID"]
        let formatID: Int? = rawFormatID != nil ? Int(rawFormatID!) : nil
        let rawServiceCode = data["serviceCode"]
        let serviceCode: Int? = rawServiceCode != nil ? Int(rawServiceCode!) : nil
        let reason = fallbackReason != .none ? fallbackReason : .iccError
        
        return MSRFallbackCardData.cardData(cardholderName: data["cardholderName"],
                                            encryptedTrack1: data["encTrack1"],
                                            encryptedTrack2: data["encTrack2"],
                                            expirationDate: data["expiryDate"],
                                            formatID: formatID,
                                            ksn: data["ksn"],
                                            maskedPAN: data["maskedPAN"],
                                            serialNumber: data["serialNumber"],
                                            serviceCode: serviceCode,
                                            fallbackReason: reason,
                                            terminalType: terminalType)
    }
    
    func createCardData(data: [String: String]) -> MSRCardData? {
        let rawFormatID = data["formatID"]
        let formatID: Int? = rawFormatID != nil ? Int(rawFormatID!) : nil
        let rawServiceCode = data["serviceCode"]
        let serviceCode: Int? = rawServiceCode != nil ? Int(rawServiceCode!) : nil
        
        return MSRCardData.cardData(cardholderName: data["cardholderName"],
                                    encryptedTrack1: data["encTrack1"],
                                    encryptedTrack2: data["encTrack2"],
                                    expirationDate: data["expiryDate"],
                                    formatID: formatID,
                                    ksn: data["ksn"],
                                    maskedPAN: data["maskedPAN"],
                                    serialNumber: data["serialNumber"],
                                    serviceCode: serviceCode,
                                    terminalType: terminalType)
    }
}

extension BBPOSTerminal {
    func onReturnDeviceInfo(_ deviceInfo: [AnyHashable : Any]!) {
        otaDelegate?.terminalVersionDetails(info: deviceInfo)
    }
}

extension BBPOSTerminal: BBDeviceOTAControllerDelegate {
    func onReturnTargetVersionListResult(_ result: BBDeviceOTAResult, list: [Any]!, responseMessage: String!) {
        otaDelegate?.listOfVersionsFor(type: otaUpdateType ?? .firmware, results: list)
    }
    
    func onReturnOTAProgress(_ percentage: Float) {
        otaDelegate?.otaUpdateProgress(percentage: percentage)
    }
    
    func onReturnRemoteFirmwareUpdate(_ result: BBDeviceOTAResult, responseMessage: String!) {
        let otaResult: TerminalOTAResult
        switch result {
        case .success:
            otaResult = .success
        default:
            otaResult = TerminalOTAResult(rawValue: result.rawValue) ?? TerminalOTAResult.setupError
        }
        
        otaDelegate?.terminalOTAResult(resultType: otaResult, info: nil, error: GatewayError.generalError)
    }
    
    func onReturnRemoteConfigUpdate(_ result: BBDeviceOTAResult, responseMessage: String!) {
        let otaResult: TerminalOTAResult
        switch result {
        case .success:
            otaResult = .success
        default:
            otaResult = TerminalOTAResult(rawValue: result.rawValue) ?? TerminalOTAResult.setupError
        }
        
        otaDelegate?.terminalOTAResult(resultType: otaResult, info: nil, error: GatewayError.generalError)
    }
    
    func onReturnSetTargetVersionResult(_ result: BBDeviceOTAResult, responseMessage: String!) {
        let otaResult: TerminalOTAResult
        switch result {
        case .success:
            otaResult = .success
        default:
            otaResult = TerminalOTAResult(rawValue: result.rawValue) ?? TerminalOTAResult.setupError
        }
        
        otaDelegate?.onReturnSetTargetVersion(resultType: otaResult, type: otaUpdateType ?? .firmware, message: responseMessage)
    }
    
    func onReturnRemoteKeyInjectionResult(_ result: BBDeviceOTAResult, responseMessage: String!) {
        let otaResult: TerminalOTAResult
        switch result {
        case .success:
            otaResult = .success
        default:
            otaResult = TerminalOTAResult(rawValue: result.rawValue) ?? TerminalOTAResult.setupError
        }
        otaDelegate?.terminalOTAResult(resultType: otaResult, info: nil, error: GatewayError.generalError)
    }
}

extension BBPOSTerminal {

    private func saveLastDevice(peripheral: CBPeripheral) {
        let saved = BBPOSDevice(identifier: peripheral.identifier.uuidString,
                                     name: peripheral.name ?? "")
        if let data = try? JSONEncoder().encode(saved) {
            UserDefaults.standard.set(data, forKey: savedDeviceKey)
            UserDefaults.standard.synchronize()
        }
    }

    private func loadLastDevice() -> BBPOSDevice? {
        guard let data = UserDefaults.standard.data(forKey: savedDeviceKey) else { return nil }
        return try? JSONDecoder().decode(BBPOSDevice.self, from: data)
    }

    private func clearLastDevice() {
        UserDefaults.standard.removeObject(forKey: savedDeviceKey)
    }
}
