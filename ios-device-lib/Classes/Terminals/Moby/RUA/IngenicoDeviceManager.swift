//
//  IngenicoDeviceManager.swift
//  ios-device-lib
//

import Foundation
import os.log
import ExternalAccessory
import AVFoundation

// MARK: - Private Constants

private let pairedDeviceKey           = "PairedDevices"
private let ingenicoErrorDomain       = "com.heartland.Heartland-iOS-SDK.ingenico"
private let ruaDeviceHardResetPayload = "FF880A0000"
private let insertICCOnly             = "C00C"
private let configuredDeviceKey       = "ConfiguredDevices"

// MARK: - IngenicoDeviceManager

class IngenicoDeviceManager: NSObject {

    // MARK: - Private Properties

    private var deviceManager: RUADeviceManager?
    private var configManager: RUAConfigurationManager?
    private var transactionManager: RUATransactionManager?
    private var selectedRUADevice: RUADevice?
    private var deviceType: RUADeviceType = RUADeviceTypeMOBY5500
    private var discoveredDevices: [RUADevice] = []
    private var pairedDevices: [RUADevice] = []
    private var configuredDevices: Set<String> = []
    private var terminalTender: TerminalTender?
    private var configuration: IngenicoDeviceConfiguration?
    private var configurationProgress: Int = 0
    private var configurationStepCount: Int = 0
    private weak var delegate: IngenicoDeviceManagerDelegate?
    private var currentPublicKeyIndex: Int = 0
    private var deviceSerialNumber: String?
    private var kernelVersionNumber: String?
    private var aids: [AID]?
    private var aidValue: String?
    private var dipCount: Int = 0
    private var fallbackRequested: Bool = false
    private var inPairingFlow: Bool = false
    private var initialized: Bool = false
    private var debug: Bool = false
    private var autoConnectReader: Bool = false
    private var transactionStatus: TransactionStatus = .offlineDecline

    // MARK: - Stored Response-Handler Closures

    private var progressResponse: ((RUAProgressMessage, String?) -> Void)?
    private var clearAidsResponse: ((RUAResponse?) -> Void)?
    private var aidConfigurationResponse: ((RUAResponse?) -> Void)?
    private var dolConfigurationResponse: ((RUAResponse?) -> Void)?
    private var onlineDOLConfigurationResponse: ((RUAResponse?) -> Void)?
    private var responseDOLConfigurationResponse: ((RUAResponse?) -> Void)?
    private var clearPublicKeyConfigurationResponse: ((RUAResponse?) -> Void)?
    private var publicKeyResponse: ((RUAResponse?) -> Void)?
    private var handleSerialNumberResponse: ((RUAResponse?) -> Void)?

    // MARK: - BLE-Specific Properties

    private var selectedDevice: RUADevice?
    private var isUserInitiatedDisconnect: Bool = false
    private var isSilentRelease: Bool = false
    private var pendingReconnect: Bool = false
    private var retryCount: Int = 0
    private var didntPushYet: Bool = false
    private var connectedDeviceSerialNumber: String?
    private var ledConfirmationMoby5500Cb: RUALedPairingConfirmationCallback?
    private let maxRetries = 2

    private var log: OSLog!
    
    private let progressMessage = RUAProgressMessage(rawValue: 0)

    // MARK: - Init

    public required init(config terminalConfig: RUATerminalConfig,
                         autoConnect: Bool,
                         delegate: IngenicoDeviceManagerDelegate) {
        self.debug = terminalConfig.isDebug
        self.delegate = delegate
    
        self.deviceType = IngenicoDeviceManager.ruaDeviceType(from: terminalConfig.terminalType)
        self.deviceManager = RUA.getDeviceManager(deviceType)
        self.configManager = deviceManager?.getConfigurationManager()
        self.configManager?.setCommandTimeout(30000)
        self.didntPushYet = false

        super.init()

        log = OSLog(
            subsystem: "com.heartland.Heartland-iOS-SDK.ingenicoterminals.plist",
            category: RUAEnumerationHelper.ruaDeviceType_(toString: deviceManager?.getType() ?? RUADeviceTypeUnknown) ?? ""
        )

        EAAccessoryManager.shared().registerForLocalNotifications()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(eaDeviceConnected(_:)),
            name: .EAAccessoryDidConnect,
            object: nil
        )

        RUA.setProductionMode(terminalConfig.isProduction)
        RUA.enableDebugLogMessages(debug)

        discoveredDevices = []
        pairedDevices     = []
        currentPublicKeyIndex = 0
        configuredDevices = []

        setupProgressResponseHandler()
        resetDeviceManager()

        if autoConnect {
            initializeDevice()
        }
    }

    deinit {
        EAAccessoryManager.shared().unregisterForLocalNotifications()
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Private Helpers

private extension IngenicoDeviceManager {

    static func ruaDeviceType(from type: RUATerminalType) -> RUADeviceType {
        switch type {
        case .rp450c:   return RUADeviceTypeRP450c
        case .rp350x:   return RUADeviceType(rawValue: 1)
        case .g4x_g5x:  return RUADeviceType(rawValue: 0)
        case .rp45BT:   return RUADeviceTypeRP45BT
        case .moby3000: return RUADeviceTypeMOBY3000
        case .moby8500: return RUADeviceTypeMOBY8500
        case .moby5500: return RUADeviceTypeMOBY5500
        default:        return RUADeviceTypeRP450c
        }
    }

    static func cardDataSourceType(_ type: String?) -> CardDataSource {
        guard let type = type else { return .swipe }
        switch type {
        case "91":       return .nfc
        case "02", "90": return .swipe
        case "07":       return .emvContactless
        case "05", "95": return .emv
        case "00":       return .emv
        default:         return .none
        }
    }

    @objc func eaDeviceConnected(_ notification: Notification) {
        guard !inPairingFlow, autoConnectReader else { return }
        guard let userInfo = notification.userInfo,
              let accessory = userInfo[EAAccessoryKey] as? EAAccessory else { return }
        let landiProtocols = ["com.landicorp.datapath", "com.landi.datapath"]
        if accessory.protocolStrings.contains(where: { landiProtocols.contains($0) }) {
            deviceManager?.initializeDevice(self)
        }
    }

    func resetDeviceManager() {
        dipCount       = 0
        terminalTender = nil
        if deviceManager?.isReady() == true,
           deviceManager?.getType() == RUADeviceType(rawValue: 0) {
            releaseDevice()
        }
    }

    func releaseDevice() {
        deviceManager?.releaseDevice(self)
    }

    func isBluetoothSupported() -> Bool {
        let t = deviceManager?.getType()
        return t == RUADeviceTypeRP450c   ||
               t == RUADeviceTypeRP45BT   ||
               t == RUADeviceTypeMOBY3000 ||
               t == RUADeviceTypeMOBY8500
    }

    func consoleLog(_ data: String?) {
        guard debug, let data = data else { return }
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm:ss"
        NSLog("%@:%@\n", fmt.string(from: Date()), data)
    }

    var noopProgress: OnProgress { { _, _ in } }
    var noopResponse: OnResponse { { _ in } }
}

// MARK: - Setup Progress Response Handlers

extension IngenicoDeviceManager {

    func setupProgressResponseHandler() {

        progressResponse = { [weak self] messageType, additionalMessage in
            guard let self = self else { return }
            if self.debug {
                print(RUAEnumerationHelper.ruaProgressMessage_(toString: messageType) ?? "")
            }

            let progressMessage: ProgressMessage
            switch messageType {
            case .pleaseInsertCard:
                progressMessage = additionalMessage == insertICCOnly ? .insertCard : .presentCard
            case .pleaseRemoveCard:
                self.dipCount += 1
                progressMessage = .removeCard
            case .swipeDetected:
                progressMessage = .swipeDetected
            case .waitingforCardSwipe:
                progressMessage = .presentCard
            case .iccErrorSwipeCard:
                self.dipCount += 1
                self.fallbackRequested = true
                progressMessage = .iccErrorSwipeCard
            case .swipeErrorReswipe:
                progressMessage = .swipeErrorReswipe
            case .magCardDataInsertCard:
                progressMessage = .insertCard
            case .cardInserted:
                self.dipCount += 1
                progressMessage = .cardInserted
            case .cardReadError:
                progressMessage = .cardReadError
            case .contactlessInterfaceFailedTryContact, .contactlessTransactionRevertedToContact:
                progressMessage = .contactlessInterfaceFailedTryContact
            case .errorReadingContactlessCard:
                progressMessage = .errorReadingContactlessCard
            case .multipleContactlessCardsDetected:
                progressMessage = .multipleContactlessCardsDetected
            case .swipeErrorReswipeMagStripe:
                progressMessage = .swipeErrorReswipeMagStripe
            case .tapDetected:
                progressMessage = .tapDetected
            case .contactlessCardStillInField:
                progressMessage = .contactlessCardStillInField
            case .pleaseSeePhone:
                progressMessage = .pleaseSeePhone
            case .presentCardAgain:
                progressMessage = .presentCardAgain
            case .cardRemoved:
                self.dipCount += 1
                progressMessage = .cardRemoved
            case .completeCardRemove:
                progressMessage = .completeCardRemove
            case .removeCard:
                progressMessage = .removeCard
            case .insertOrSwipeCard:
                progressMessage = .insertOrSwipeCard
            case .cardReadOkRemoveCard:
                progressMessage = .cardReadOkRemoveCard
            case .processingDoNotRemoveCard:
                progressMessage = .processingDoNotRemoveCard
            case .notAcceptedRemoveCard:
                progressMessage = .notAcceptedRemoveCard
            case .cardError:
                progressMessage = .cardError
            case .cardErrorRemoveCard:
                progressMessage = .cardErrorRemoveCard
            case .cancelledRemoveCard:
                progressMessage = .cancelledRemoveCard
            case .transactionVoidRemoveCard:
                progressMessage = .transactionVoidRemoveCard
            case .unknownAID:
                self.fallbackRequested = true
                progressMessage = .unknownAID
            case .reinsertCard:
                progressMessage = .reinsertCard
            default:
                return
            }

            if progressMessage == .removeCard,
               self.terminalTender?.cardDataSource != .emv { return }

            if messageType != .commandSent {
                self.delegate?.onTransactionStatus(progressMessage,
                                                   withIngenicoResponse: self.terminalTender)
            }
        }

        handleSerialNumberResponse = { [weak self] optResponse in
            guard let self = self, let response = optResponse else { return }
            if response.responseCode == RUAResponseCodeError {
                self.handleRuaResponseError(response)
            } else if let values = response.responseData as? [NSNumber: Any] {
                let key = NSNumber(value: RUAParameter.interfaceDeviceSerialNumber.rawValue)
                self.terminalTender?.deviceSerialNumber = values[key] as? String
                self.configureDeviceWithSerialNumber(values[key] as? String)
            }
        }

        clearPublicKeyConfigurationResponse = { [weak self] optResponse in
            guard let self = self, let response = optResponse else { return }
            if response.responseCode == RUAResponseCodeError {
                self.handleRuaResponseError(response)
            } else {
                self.consoleLog(self.ruaResponse(toString: response))
                self.configurationProgress += 1
                self.delegate?.onDeviceConfigurationProgress(self.configurationProgress,
                                                             total: self.configurationStepCount,
                                                             isFailed: false)
                self.setupAIDS()
            }
        }

        clearAidsResponse = { [weak self] optResponse in
            guard let self = self, let response = optResponse else { return }
            if response.responseCode == RUAResponseCodeError {
                self.handleRuaResponseError(response)
            } else {
                self.submitAIDs()
            }
        }

        aidConfigurationResponse = { [weak self] optResponse in
            guard let self = self, let response = optResponse else { return }
            if self.debug { print(self.ruaResponse(toString: response)) }
            if response.responseCode == RUAResponseCodeError {
                self.handleRuaResponseError(response)
            } else {
                self.consoleLog(self.ruaResponse(toString: response))
                self.configurationProgress += 1
                self.delegate?.onDeviceConfigurationProgress(self.configurationProgress,
                                                             total: self.configurationStepCount,
                                                             isFailed: false)
                self.submitPublicKeys()
            }
        }

        publicKeyResponse = { [weak self] optResponse in
            guard let self = self, let response = optResponse else { return }
            if self.debug { print(self.ruaResponse(toString: response)) }
            if response.responseCode == RUAResponseCodeError {
                self.handleRuaResponseError(response)
            } else {
                self.configurationProgress += 1
                self.delegate?.onDeviceConfigurationProgress(self.configurationProgress,
                                                             total: self.configurationStepCount,
                                                             isFailed: false)
                let pkList = self.configuration?.publicKeyList ?? []
                if (self.configuration?.currentPublicKeyIndex ?? 0) < pkList.count {
                    self.submitPublicKeys()
                } else {
                    self.setupOnlineDOL()
                }
            }
        }

        onlineDOLConfigurationResponse = { [weak self] optResponse in
            guard let self = self, let response = optResponse else { return }
            if self.debug { print(self.ruaResponse(toString: response)) }
            if response.responseCode == RUAResponseCodeError {
                self.handleRuaResponseError(response)
            } else {
                self.configurationProgress += 1
                self.delegate?.onDeviceConfigurationProgress(self.configurationProgress,
                                                             total: self.configurationStepCount,
                                                             isFailed: false)
                self.setupResponseDOL()
            }
        }

        responseDOLConfigurationResponse = { [weak self] optResponse in
            guard let self = self, let response = optResponse else { return }
            if self.debug { print(self.ruaResponse(toString: response)) }
            if response.responseCode == RUAResponseCodeError {
                self.handleRuaResponseError(response)
            } else {
                self.configurationProgress += 1
                self.delegate?.onDeviceConfigurationProgress(self.configurationProgress,
                                                             total: self.configurationStepCount,
                                                             isFailed: false)
                self.setupDOLs()
            }
        }

        dolConfigurationResponse = { [weak self] optResponse in
            guard let self = self, let response = optResponse else { return }
            if self.debug { print(self.ruaResponse(toString: response)) }
            if response.responseCode == RUAResponseCodeError {
                self.handleRuaResponseError(response)
            } else {
                self.configurationProgress += 1
                self.delegate?.onDeviceConfigurationProgress(self.configurationProgress,
                                                             total: self.configurationStepCount,
                                                             isFailed: false)
                self.deviceConfigurationComplete(response)
            }
        }
    }
}

// MARK: - Device Configuration

extension IngenicoDeviceManager {

    func configureDeviceWithSerialNumber(_ serialNumber: String?) {
        deviceSerialNumber = serialNumber
        currentPublicKeyIndex = 0
        configuration?.currentPublicKeyIndex = 0
        configuration?.connectedDeviceSerialNumber = serialNumber ?? ""

        if let sn = serialNumber, !configuredDevices.contains(sn) {
            configuration?.initialized = false
            clearPublicKeys()
        } else {
            setupExpectedDOLs()
        }
    }

    func setupExpectedDOLs() {
        let cmgr = deviceManager?.getConfigurationManager()
        cmgr?.setExpectedAmountDOL(getAmountDolsList())
        cmgr?.setExpectedContactlessOnlineDOL(getContactlessOnlineDolsList())
        cmgr?.setExpectedContactlessResponseDOL(getContactlessResponseDolsList())
        cmgr?.setExpectedResponseDOL(getResponseDolsList())
        cmgr?.setExpectedOnlineDOL(getOnlineDolsList())
        deviceConfigurationComplete(nil)
    }

    func deviceConfigurationComplete(_ response: RUAResponse?) {
        if response?.responseCode == RUAResponseCodeSuccess || response == nil {
            configuration?.initialized = true
            if let sn = configuration?.connectedDeviceSerialNumber {
                configuredDevices.insert(sn)
            }
            saveConfiguredDevices()
            delegate?.onTransactionStatus(.configurationComplete, withIngenicoResponse: nil)
        } else if let response = response {
            handleRuaResponseError(response)
        }
    }

    func setupOnlineDOL() {
        guard let progress = progressResponse,
              let onlineDOL = configuration?.onlineDOL,
              let response = onlineDOLConfigurationResponse else { return }
        configManager?.setOnlineDOL(onlineDOL, progress: progress, response: response)
    }

    func setupDOLs() {
        guard let progress = progressResponse,
              let amountDOL = configuration?.amountDOL,
              let response = dolConfigurationResponse else { return }
        configManager?.setAmountDOL(amountDOL, progress: progress, response: response)
    }

    func setupResponseDOL() {
        guard let progress = progressResponse,
              let responseDOL = configuration?.responseDOL,
              let response = responseDOLConfigurationResponse else { return }
        configManager?.setResponseDOL(responseDOL, progress: progress, response: response)
    }

    func submitAIDs() {
        guard let config = configuration,
              let progress = progressResponse,
              let response = aidConfigurationResponse else { return }
        configManager?.submitAIDList(config.aidsList, progress: progress, response: response)
    }

    func setupAIDS() {
        guard let progress = progressResponse,
              let response = clearAidsResponse else { return }
        configManager?.clearAIDSList(progress, response: response)
    }

    func submitPublicKeys() {
        guard let config = configuration,
              let progress = progressResponse,
              let response = publicKeyResponse else { return }
        let pkList = config.publicKeyList
        let idx = Int(config.currentPublicKeyIndex)
        guard idx < pkList.count,
              let key = pkList[idx] as? RUAPublicKey else { return }
        configuration?.currentPublicKeyIndex += 1
        configManager?.submitPublicKey(key, progress: progress, response: response)
    }

    func clearPublicKeys() {
        guard let progress = progressResponse,
              let response = clearPublicKeyConfigurationResponse else { return }
        configManager?.clearPublicKeys(progress, response: response)
    }

    func saveConfiguredDevices() {
        let archiveArray: [Data] = configuredDevices.compactMap {
            try? NSKeyedArchiver.archivedData(withRootObject: $0, requiringSecureCoding: false)
        }
        UserDefaults.standard.set(archiveArray, forKey: configuredDeviceKey)
        UserDefaults.standard.synchronize()
    }

    func getConnectedDeviceList() -> Set<String> {
        guard let archiveArray = UserDefaults.standard.object(forKey: configuredDeviceKey) as? [Data] else { return [] }
        let devices: [String] = archiveArray.compactMap {
            try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSString.self, from: $0) as? String
        }
        return Set(devices)
    }
}

// MARK: - Device Initialization

extension IngenicoDeviceManager {

    func initializeDevice() {
        if isBluetoothSupported() {
            if let dev = selectedRUADevice {
                _ = configManager?.activate(dev)
            }
        } else {
            delegate?.deviceError(NSError(
                domain: ingenicoErrorDomain, code: 200,
                userInfo: [NSLocalizedDescriptionKey:
                    "Selected device failed to connect or bluetooth is not supported"]
            ))
            return
        }
        deviceManager?.initializeDevice(self, pairingListener: self)
    }

    func onDeviceConnected() {
        delegate?.deviceConnected()
        if let device = selectedRUADevice {
            startDeviceConfiguration(device)
        }
    }

    func startDeviceConfiguration(_ device: RUADevice) {
        delegate?.onDeviceConfigurationProgress(0, total: configurationStepCount, isFailed: false)

        if deviceType == RUADeviceType(rawValue: 0) {
            delegate?.onTransactionStatus(.configurationComplete, withIngenicoResponse: nil)
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                guard let self = self else { return }
                self.configManager?.readVersion(
                    self.progressResponse ?? self.noopProgress,
                    response: { [weak self] response in
                        guard let self = self, let response = response else { return }
                        if self.debug { print(self.ruaResponse(toString: response)) }

                        if response.responseCode == RUAResponseCodeError,
                           response.errorCode == RUAErrorCodeReaderDisconnected {
                            if device.communicationInterface == RUACommunicationInterfaceBluetooth {
                                _ = self.configManager?.activate(device)
                            }
                            self.deviceManager?.initializeDevice(self)
                        } else if response.responseCode == RUAResponseCodeError {
                            self.handleRuaResponseError(response)
                        } else {
                            self.handleReadVersionResponse(response)
                        }
                    }
                )
            }
        }
    }

    func handleReadVersionResponse(_ response: RUAResponse) {
        if debug { print(ruaResponse(toString: response)) }
        if let info = (response.responseData as? [NSNumber: Any])?[NSNumber(value: RUAParameter.readerVersionInfo.rawValue)] as? RUAReaderVersionInfo {
            deviceSerialNumber  = info.productSerialNumber?.trimmingCharacters(in: CharacterSet.whitespaces)
            kernelVersionNumber = info.emvKernelVersion?.trimmingCharacters(in: CharacterSet.whitespaces)
        }
        configManager?.getReaderCapabilities(
            progressResponse ?? noopProgress,
            response: handleSerialNumberResponse ?? noopResponse
        )
    }

    func setupAIDSandPublicKeys() {
        let configuredList = getConnectedDeviceList()
        if let sn = connectedDeviceSerialNumber, configuredList.contains(sn) {
            initialized = true
        }
        setupExpectedDOLs()
        pushProvisionFileFromCloud()
    }

    func pushProvisionFileFromCloud() {
        // For non-Moby5500 devices, configuration proceeds via AIDs/keys/DOLs.
        if let device = selectedRUADevice {
            startDeviceConfiguration(device)
        }
    }
}

// MARK: - Transaction Methods

extension IngenicoDeviceManager {

    func waitForMsrSwipe() {
        transactionManager?.wait(
            forCardRemoval: progressMessage?.rawValue ?? 0,
            response: { [weak self] response in
                guard let self = self, let response = response else { return }
                self.handleMsrResponse(response)
            }
        )
    }

    func handleMsrResponse(_ response: RUAResponse) {
        if response.responseCode != RUAResponseCodeSuccess {
            delegate?.onTransactionStatus(.swipeErrorReswipe, withIngenicoResponse: nil)
            waitForMsrSwipe()
        } else {
            aidValue = (response.responseData as? [NSNumber: Any])?[NSNumber(value: RUAParameter.applicationIdentifier.rawValue)] as? String
            updateTransactionAfterTransactionDataResponse(response)
            deviceManager?.getTransactionManager().send(
                .commandEMVTransactionStop,
                withParameters: nil,
                progress: progressResponse ?? noopProgress
            ) { [weak self] _ in
                self?.delegate?.onTransactionStatus(.goOnlineRequested,
                                                    withIngenicoResponse: self?.terminalTender)
            }
        }
    }

    func updateTransactionAfterTransactionDataResponse(_ response: RUAResponse) {
        logRuaParamDictionary(response.responseData as? [NSNumber: Any])
        guard let resp = response.responseData as? [NSNumber: Any] else { return }

        let tlvData            = resp[NSNumber(value: RUAParameter.emvtlvData.rawValue)] as? String
        let entryMode          = resp[NSNumber(value: RUAParameter.posEntryMode.rawValue)] as? String
        let packEncryptedTrack = resp[NSNumber(value: RUAParameter.packEncryptedTrackData.rawValue)] as? String
        let cvmResult          = resp[NSNumber(value: RUAParameter.cardholderVerificationMethodResult.rawValue)] as? String

        if terminalTender == nil { terminalTender = TerminalTender() }

        if fallbackRequested {
            terminalTender?.fallbackSwipe = fallbackRequested
            if dipCount >= 3 {
                terminalTender?.emvFallbackCondition = .iccError
                terminalTender?.lastChipRead = .failed
            } else {
                terminalTender?.emvFallbackCondition = .emptyCandidateList
                terminalTender?.lastChipRead = .successful
            }
            terminalTender?.cardDataSource = .fallbackSwipe
        } else {
            terminalTender?.cardDataSource = IngenicoDeviceManager.cardDataSourceType(entryMode)
            terminalTender?.lastChipRead   = .successful
        }

        terminalTender?.tlvData                        = tlvData
        terminalTender?.formatID                       = resp[NSNumber(value: RUAParameter.formatID.rawValue)] as? String
        terminalTender?.encryptedTrackData             = resp[NSNumber(value: RUAParameter.encryptedTrack.rawValue)] as? String
        terminalTender?.track1Data                     = resp[NSNumber(value: RUAParameter.track1Data.rawValue)] as? String
        terminalTender?.track2Data                     = resp[NSNumber(value: RUAParameter.track2Data.rawValue)] as? String
        terminalTender?.packEncryptedTrackData         = packEncryptedTrack
        terminalTender?.ksn                            = resp[NSNumber(value: 353)] as? String
        terminalTender?.cardHolderName                 = resp[NSNumber(value: RUAParameter.cardHolderName.rawValue)] as? String
        terminalTender?.expirationDate                 = resp[NSNumber(value: RUAParameter.cardExpDate.rawValue)] as? String
        terminalTender?.cardholderAuthenticationMethod = TerminalTender.cardholderAuthenticationMethodfromTlv(cvmResult)
        terminalTender?.redactedPan                    = resp[NSNumber(value: RUAParameter.redactedCardNumber.rawValue)] as? String
        terminalTender?.maskedPan                      = resp[NSNumber(value: 425)] as? String
        terminalTender?.serviceCode                    = resp[NSNumber(value: RUAParameter.serviceCode.rawValue)] as? String
        terminalTender?.deviceSerialNumber             = deviceSerialNumber
        terminalTender?.kernelVersionNumber            = kernelVersionNumber
    }

    func updateTransactionAfterCompleteTransactionResponse(_ response: RUAResponse) {
        guard let resp = response.responseData as? [NSNumber: Any] else { return }
        let cvmResult = resp[NSNumber(value: RUAParameter.cardholderVerificationMethodResult.rawValue)] as? String
        let entryMode = resp[NSNumber(value: RUAParameter.posEntryMode.rawValue)] as? String
        terminalTender?.cardDataSource             = IngenicoDeviceManager.cardDataSourceType(entryMode)
        terminalTender?.tlvData                    = resp[NSNumber(value: RUAParameter.emvtlvData.rawValue)] as? String
        terminalTender?.encryptedTrackData         = resp[NSNumber(value: RUAParameter.packEncryptedTrackData.rawValue)] as? String
        terminalTender?.ksn                        = resp[NSNumber(value: 353)] as? String
        terminalTender?.cardholderAuthenticationMethod = TerminalTender.cardholderAuthenticationMethodfromTlv(cvmResult)
        terminalTender?.deviceSerialNumber         = deviceSerialNumber
        terminalTender?.kernelVersionNumber        = kernelVersionNumber
    }

    func getEMVFinalAppSelectionParameters(_ applicationIdentifier: String?) -> [NSNumber: Any] {
        [NSNumber(value: RUAParameter.applicationIdentifier.rawValue): applicationIdentifier ?? "A0000000041010"]
    }

    func sendSelectAidCommand(_ aidValue: String?) {
        self.aidValue = aidValue
        transactionManager?.send(
            .commandEMVFinalApplicationSelection,
            withParameters: getEMVFinalAppSelectionParameters(aidValue),
            progress: progressResponse ?? noopProgress
        ) { [weak self] ruaResponse in
            guard let self = self, let ruaResponse = ruaResponse else { return }
            if ruaResponse.responseCode == RUAResponseCodeSuccess {
                let responseType = ruaResponse.responseType
                self.aidValue = (ruaResponse.responseData as? [NSNumber: Any])?[NSNumber(value: RUAParameter.applicationIdentifier.rawValue)] as? String
                self.updateTransactionAfterTransactionDataResponse(ruaResponse)

                switch responseType {
                case RUAResponseTypeContactEMVAmountDOL, RUAResponseTypeContactLessEMVAmountDOL:
                    self.delegate?.onTransactionStatus(.confirmAmount,
                                                       withIngenicoResponse: self.terminalTender)
                case RUAResponseTypeContactLessEMVResponseDOL:
                    break
                case RUAResponseTypeListOfApplicationIdentifiers:
                    self.handleListOfAidsResponse(ruaResponse)
                default:
                    self.sendEMVTransactionDataCommand()
                }
            } else {
                self.transactionManager?.send(
                    .commandEMVTransactionStop,
                    withParameters: nil,
                    progress: self.progressResponse ?? self.noopProgress
                ) { [weak self] _ in
                    self?.delegate?.onTransactionStatus(.goOnlineRequested,
                                                        withIngenicoResponse: self?.terminalTender)
                }
            }
        }
    }

    func handleListOfAidsResponse(_ response: RUAResponse) {
        let listOfAids = response.listOfApplicationIdentifiers ?? []
        let aidList: [AID] = (listOfAids as? [RUAApplicationIdentifier] ?? []).map { appID in
            let aid = AID()
            aid.rid = appID.rid
            aid.pix = appID.pix
            aid.applicationIdentifier = appID.aid
            aid.preferredName = appID.applicationLabel
            return aid
        }
        self.aids = aidList
        delegate?.selectAid(aidList)
    }

    func sendEMVTransactionDataCommand() {
        transactionManager?.send(
            .commandEMVTransactionData,
            withParameters: getEMVTransactionDataParameters(aidValue),
            progress: progressResponse ?? noopProgress
        ) { [weak self] response in
            guard let self = self, let response = response else { return }
            if response.responseCode == RUAResponseCodeSuccess {
                self.updateTransactionAfterTransactionDataResponse(response)
                let resp     = response.responseData as? [NSNumber: Any]
                let cid      = resp?[NSNumber(value: RUAParameter.cryptogramInformationData.rawValue)] as? String
                let terminal = resp?[NSNumber(value: RUAParameter.terminalDecisionafterGenerateAC.rawValue)] as? String
                self.checkCID(cid, andTerminalDecisionAfterGenerateAC: terminal)
            } else {
                self.handleRuaResponseError(response)
            }
        }
    }

    func sendEMVTransactionDataCommandWithAID(_ aidValue: String?) {
        self.aidValue = aidValue
        sendEMVTransactionDataCommand()
    }

    func handleEmvStartTransactionResponse(_ response: RUAResponse) {
        let responseType = response.responseType
        let resp         = response.responseData as? [NSNumber: Any]
        aidValue = resp?[NSNumber(value: RUAParameter.applicationIdentifier.rawValue)] as? String

        updateTransactionAfterTransactionDataResponse(response)

        switch responseType {
        case RUAResponseTypeMagneticCardData:
            deviceManager?.getTransactionManager().send(
                .commandEMVTransactionStop,
                withParameters: nil,
                progress: progressResponse ?? noopProgress
            ) { [weak self] _ in
                self?.delegate?.onTransactionStatus(.goOnlineRequested,
                                                    withIngenicoResponse: self?.terminalTender)
            }
        case RUAResponseTypeContactEMVAmountDOL, RUAResponseTypeContactLessEMVAmountDOL:
            delegate?.onTransactionStatus(.confirmAmount, withIngenicoResponse: terminalTender)
        case RUAResponseTypeContactLessEMVResponseDOL:
            break
        case RUAResponseTypeListOfApplicationIdentifiers:
            handleListOfAidsResponse(response)
        default:
            sendEMVTransactionDataCommand()
        }
    }

    func handleCompleteTransactionResponse(_ response: RUAResponse) {
        terminalTender?.tlvData = (response.responseData as? [NSNumber: Any])?[NSNumber(value: RUAParameter.emvtlvData.rawValue)] as? String
        if response.responseCode == RUAResponseCodeError {
            handleRuaResponseError(response)
        } else {
            let resp     = response.responseData as? [NSNumber: Any]
            let cid      = resp?[NSNumber(value: RUAParameter.cryptogramInformationData.rawValue)] as? String
            let terminal = resp?[NSNumber(value: RUAParameter.terminalDecisionafterGenerateAC.rawValue)] as? String
            terminalTender?.cardHolderName = resp?[NSNumber(value: RUAParameter.cardHolderName.rawValue)] as? String
            checkCID(cid, andTerminalDecisionAfterSecondGenerateAC: terminal)
        }
    }

    // MARK: CID Handling – First Generate AC

    func checkCID(_ cidValue: String?, andTerminalDecisionAfterGenerateAC terminalDecisionValue: String?) {
        let progress = progressResponse ?? noopProgress
        if cidValue == "00" || checkTerminalDecisionValue(terminalDecisionValue) == .declined {
            deviceManager?.getTransactionManager().send(
                .commandEMVTransactionStop, withParameters: nil, progress: progress
            ) { [weak self] response in
                guard let self = self, let response = response else { return }
                self.handleCidOfflineDecline(response)
            }
        } else if cidValue == "40" {
            deviceManager?.getTransactionManager().send(
                .commandEMVTransactionStop, withParameters: nil, progress: progress
            ) { [weak self] response in
                guard let self = self, let response = response else { return }
                self.handleCidOfflineApproved(response)
            }
        } else if cidValue == "80" {
            delegate?.onTransactionStatus(.goOnlineRequested, withIngenicoResponse: terminalTender)
        } else if cidValue == nil || cidValue == "" {
            handleTerminalDecisionValue(terminalDecisionValue)
        }
    }

    // MARK: CID Handling – Second Generate AC

    func checkCID(_ cidValue: String?, andTerminalDecisionAfterSecondGenerateAC terminalDecisionValue: String?) {
        let progress = progressResponse ?? noopProgress
        if cidValue == "00" || terminalDecisionValue == "00" {
            transactionManager?.send(
                .commandEMVTransactionStop, withParameters: nil, progress: progress
            ) { [weak self] response in
                guard let self = self, let response = response else { return }
                if response.responseCode == RUAResponseCodeError {
                    self.handleRuaResponseError(response)
                } else if self.transactionStatus == .onlineApproved || self.transactionStatus == .hostTimeout {
                    self.terminalTender?.transactionResult = .reversalRequired
                    self.terminalTender?.voidReason        = .chipDeclined
                    self.terminalTender?.transactionType   = .void
                    self.delegate?.onTransactionStatus(.reversalRequested,
                                                       withIngenicoResponse: self.terminalTender)
                } else {
                    self.terminalTender?.transactionResult = .postAuthChipDecline
                    self.delegate?.onTransactionStatus(.postAuthChipDecline,
                                                       withIngenicoResponse: self.terminalTender)
                    self.terminalTender = nil
                }
            }
        } else if cidValue == "40" {
            transactionManager?.send(
                .commandEMVTransactionStop, withParameters: nil, progress: progress
            ) { [weak self] response in
                guard let self = self, let response = response else { return }
                if response.responseCode == RUAResponseCodeError {
                    self.handleRuaResponseError(response)
                } else {
                    self.terminalTender?.transactionResult = .approved
                    self.delegate?.onTransactionStatus(.complete,
                                                       withIngenicoResponse: self.terminalTender)
                    self.terminalTender = nil
                }
            }
        } else if cidValue == nil || cidValue == "" || cidValue == "80" {
            checkTerminalDecisionValueSecondGenerateAC(terminalDecisionValue)
        }
    }

    func checkTerminalDecisionValue(_ value: String?) -> TerminalDecisionValue {
        guard let v = value, !v.isEmpty else { return .notPresent }
        switch v {
        case "01": return .approved
        case "00": return .declined
        default:   return .notPresent
        }
    }

    func handleTerminalDecisionValue(_ terminalDecisionValue: String?) {
        let progress = progressResponse ?? noopProgress
        if terminalDecisionValue == "01" {
            deviceManager?.getTransactionManager().send(
                .commandEMVTransactionStop, withParameters: nil, progress: progress
            ) { [weak self] response in
                guard let self = self, let response = response else { return }
                self.handleCidOfflineApproved(response)
            }
        } else if terminalDecisionValue == "00" {
            deviceManager?.getTransactionManager().send(
                .commandEMVTransactionStop, withParameters: nil, progress: progress
            ) { [weak self] response in
                guard let self = self, let response = response else { return }
                self.handleCidOfflineDecline(response)
            }
        }
    }

    func checkTerminalDecisionValueSecondGenerateAC(_ terminalDecisionValue: String?) {
        let progress = progressResponse ?? noopProgress
        if terminalDecisionValue == "01" {
            transactionManager?.send(
                .commandEMVTransactionStop, withParameters: nil, progress: progress
            ) { [weak self] response in
                guard let self = self, let response = response else { return }
                if response.responseCode == RUAResponseCodeError {
                    self.handleRuaResponseError(response)
                } else {
                    self.terminalTender?.transactionResult = .approved
                    self.delegate?.onTransactionStatus(.complete,
                                                       withIngenicoResponse: self.terminalTender)
                    self.terminalTender = nil
                }
            }
        } else if terminalDecisionValue == "00" {
            transactionManager?.send(
                .commandEMVTransactionStop, withParameters: nil, progress: progress
            ) { [weak self] response in
                guard let self = self, let response = response else { return }
                self.handlePostAuthDecline(response)
            }
        }
    }

    func handlePostAuthDecline(_ response: RUAResponse) {
        if response.responseCode == RUAResponseCodeError {
            handleRuaResponseError(response)
        } else if transactionStatus == .onlineApproved || transactionStatus == .hostTimeout {
            terminalTender?.transactionResult = .reversalRequired
            terminalTender?.voidReason        = .chipDeclined
            delegate?.onTransactionStatus(.reversalRequested, withIngenicoResponse: terminalTender)
        } else {
            terminalTender?.transactionResult = .postAuthChipDecline
            delegate?.onTransactionStatus(.postAuthChipDecline, withIngenicoResponse: terminalTender)
            terminalTender = nil
        }
    }

    func handleCidOfflineDecline(_ response: RUAResponse) {
        if response.responseCode == RUAResponseCodeError {
            handleRuaResponseError(response)
        } else {
            print("Transaction Declined Offline")
            transactionStatus = .offlineDecline
            terminalTender?.transactionResult = .offlineDecline
            delegate?.onTransactionStatus(.complete, withIngenicoResponse: terminalTender)
        }
    }

    func handleCidOfflineApproved(_ response: RUAResponse) {
        if response.responseCode == RUAResponseCodeError {
            handleRuaResponseError(response)
        } else {
            print("Transaction Approved Offline")
            transactionStatus = .offlineApproved
            terminalTender?.transactionResult = .offlineApproved
            delegate?.onTransactionStatus(.complete, withIngenicoResponse: terminalTender)
        }
    }

    func restartTransactionAfterDelay(_ delay: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(delay)) { [weak self] in
            guard let self = self, let tender = self.terminalTender else { return }
            self.startWithTender(tender)
        }
    }
}

// MARK: - Online Processing

extension IngenicoDeviceManager {

    
}

// MARK: - IngenicoMethods Protocol

extension IngenicoDeviceManager: IngenicoMethods {
    
    func scanForDevices() {
        deviceManager = RUA.getDeviceManager(deviceType)
        configManager = deviceManager?.getConfigurationManager()
        if !discoveredDevices.isEmpty { discoveredDevices.removeAll() }

        if deviceType == RUADeviceType(rawValue: 0) {
            deviceManager?.initializeDevice(self)
        }

        bleDispatch { [weak self] in
            guard let self = self else { return }
            self.deviceManager?.searchDevices(self)
        }
    }

    func cancelSearch() {
        deviceManager?.cancelSearch()
    }

    func connect(_ device: Device) {
        let terminal = RUADevice(name: device.name,
                                 withIdentifier: device.identifier,
                                 with: RUACommunicationInterfaceBluetooth)
        selectedRUADevice = terminal
        selectedDevice    = terminal
        initializeDevice()
    }

    func connectToDevice(_ device: RUADevice) {
        selectedDevice = RUADevice(
            name: device.name,
            withIdentifier: device.identifier,
            with: RUACommunicationInterfaceBluetooth
        )
        isUserInitiatedDisconnect = false
        retryCount = 0
    }
    
    func disconnect() {
        isUserInitiatedDisconnect = true
        retryCount = 0
        bleDispatch { [weak self] in
            guard let self = self else { return }
            self.deviceManager?.releaseDevice(self)
        }
    }

    func batteryLevel() {
        // FIXME: Complete implementation
    }

    func startWithTender(_ tender: TerminalTender) {
        if debug {
            os_log("%ld", Int(tender.amount))
        }

        if deviceManager?.isReady() != true { initializeDevice() }

        fallbackRequested = false
        dipCount          = 0
        terminalTender    = tender

        if deviceType == RUADeviceTypeMOBY3000 && debug {
            AudioServicesPlaySystemSound(1016)
        }

        transactionManager = deviceManager?.getTransactionManager()

        let parameters = getEMVStartTransactionParameters(String(tender.amount))
        if debug { logRuaParamDictionary(parameters) }

        if deviceType == RUADeviceType(rawValue: 0) {
            waitForMsrSwipe()
        } else {
            transactionManager?.send(
                .commandEMVStartTransaction,
                withParameters: parameters,
                progress: progressResponse ?? noopProgress
            ) { [weak self] response in
                guard let self = self, let response = response else { return }
                if response.responseCode == RUAResponseCodeSuccess {
                    self.handleEmvStartTransactionResponse(response)
                } else if response.errorCode == RUAErrorCodeCommandNotSupported {
                    self.waitForMsrSwipe()
                } else {
                    self.handleRuaResponseError(response)
                }
            }
        }
    }

    func confirmAmount(_ confirmed: Bool) {
        if confirmed {
            if let isChip = terminalTender?.isChipTransaction, !isChip() {
                deviceManager?.getTransactionManager().send(
                    .commandEMVTransactionStop,
                    withParameters: nil,
                    progress: progressResponse ?? noopProgress
                ) { [weak self] _ in
                    self?.delegate?.onTransactionStatus(.goOnlineRequested,
                                                        withIngenicoResponse: self?.terminalTender)
                }
            } else if terminalTender?.cardDataSource == .emvContactless {
                // TODO: (scheduled) Contactless feature
            } else {
                sendEMVTransactionDataCommand()
            }
        } else {
            cancelTransaction()
        }
    }

    func selectedAID(_ aid: AID) {
        sendSelectAidCommand(aid.applicationIdentifier)
    }

    func sendOnlineProcessingResult(_ onlineResult: HostTenderResponse) {
        transactionStatus = onlineResult.transactionStatus

        var params: [NSNumber: Any] = [:]
        var hexString = "303030303030"

        if let authCode = onlineResult.gatewayAuthCode, !authCode.isEmpty,
           let data = authCode.data(using: .utf8),
           let hex = TLVUtility.dataToHexString(data) {
            hexString = hex
        }

        params[NSNumber(value: RUAParameter.authorizationCode.rawValue)]             = hexString
        params[NSNumber(value: RUAParameter.resultofOnlineProcess.rawValue)]         = onlineResult.onlineProcessResult
        params[NSNumber(value: RUAParameter.authorizationResponseCode.rawValue)]     = onlineResult.emvIssuerAuthCode
        params[NSNumber(value: RUAParameter.authorizationResponseCodeList.rawValue)] = "59315A3159325A3259335A333030303530313034"

        if onlineResult.tender?.transactionType == .sale ||
           onlineResult.tender?.transactionType == .auth {
            if let authData = onlineResult.emvIssuerAuthenticationData, !authData.isEmpty {
                params[NSNumber(value: RUAParameter.issuerAuthenticationData.rawValue)] = TLVUtility.tagValue(fromTLV: authData)
            }
            if let issuerScripts = onlineResult.emvIssuerScripts, !issuerScripts.isEmpty {
                let tags = TLVGMParser.splitTLVData(issuerScripts) ?? []
                for tag in tags {
                    if TLVGMParser.isIssuerScriptTemplate1(tag) {
                        params[NSNumber(value: RUAParameter.issuerScript1.rawValue)] = TLVUtility.tagValue(fromTLV: tag)
                    } else if TLVGMParser.isIssuerScriptTemplate2(tag) {
                        params[NSNumber(value: RUAParameter.issuerScript2.rawValue)] = TLVUtility.tagValue(fromTLV: tag)
                    }
                }
            }
        }

        if debug {
            os_log("HostTenderResponse %@", params.description)
        }

        transactionManager?.send(
            .commandEMVCompleteTransaction,
            withParameters: params,
            progress: progressResponse ?? noopProgress
        ) { [weak self] response in
            guard let self = self, let response = response else { return }
            if self.debug {
                os_log("%@", self.ruaResponse(toString: response))
            }
            self.handleCompleteTransactionResponse(response)
        }
    }
    
    func cancelTransaction() {
        let progress = progressResponse ?? noopProgress
        if deviceType == RUADeviceType(rawValue: 0) {
            transactionManager?.cancelLastCommand()
            terminalTender?.transactionResult = .canceled
            delegate?.onTransactionStatus(.cancelled, withIngenicoResponse: terminalTender)
            resetDeviceManager()
        } else {
            transactionManager?.send(
                .commandEMVTransactionStop,
                withParameters: nil,
                progress: progress
            ) { [weak self] response in
                guard let self = self, let response = response else { return }
                if self.debug {
                    os_log("%@", self.ruaResponse(toString: response))
                }
                if response.responseCode == RUAResponseCodeError,
                   response.command != .commandEMVStartTransaction {
                    self.handleRuaResponseError(response)
                } else {
                    self.transactionManager?.cancelLastCommand()
                    self.terminalTender?.transactionResult = .canceled
                    self.delegate?.onTransactionStatus(.cancelled,
                                                       withIngenicoResponse: self.terminalTender)
                    self.resetDeviceManager()
                }
            }
        }
    }
}

// MARK: - EMV Parameter Builders

extension IngenicoDeviceManager {

    func getEMVStartTransactionParameters(_ transactionAmount: String) -> [NSNumber: Any] {
        var params: [NSNumber: Any] = [:]
        let jsonDict = loadDictionaryFromDefaultsJSON()
        if let parsed = jsonDict["RP450EMVStartTransactionParameters"] as? [String: Any] {
            for (key, value) in parsed {
                let enumKey = NSNumber(value: RUAEnumerationHelper.ruaParameter_(toEnumeration: key).rawValue)
                params[enumKey] = value
            }
        }

        let posixLocale = Locale(identifier: "en_US_POSIX")
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyMMdd"
        dateFormatter.locale = posixLocale
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HHmmss"
        timeFormatter.locale = posixLocale

        let now    = Date()
        let amount = Int(transactionAmount) ?? 0
        params[NSNumber(value: RUAParameter.amountAuthorizedBinary.rawValue)]  = String(format: "%08X", amount)
        params[NSNumber(value: RUAParameter.amountAuthorizedNumeric.rawValue)] = String(format: "%012d", amount)
        params[NSNumber(value: RUAParameter.transactionDate.rawValue)]         = dateFormatter.string(from: now)
        params[NSNumber(value: RUAParameter.transactionTime.rawValue)]         = timeFormatter.string(from: now)
        return params
    }
}

// MARK: - DOL Configuration Helpers

extension IngenicoDeviceManager {

    func getAmountDolsList() -> [NSNumber]              { dolsList("Amount") }
    func getOnlineDolsList() -> [NSNumber]              { dolsList("Online") }
    func getResponseDolsList() -> [NSNumber]            { dolsList("dols") }
    func getContactlessResponseDolsList() -> [NSNumber] { dolsList("ContactlessResponse") }
    func getContactlessOnlineDolsList() -> [NSNumber]   { dolsList("ContactlessOnline") }

    private func dolsList(_ key: String) -> [NSNumber] {
        let json = loadDictionaryFromDefaultsJSON()
        guard let cfg   = (json["processor_profile_config_list"] as? [Any])?.first as? [String: Any],
              let dols  = cfg["dols"] as? [String: Any],
              let names = dols[key] as? [String] else { return [] }
        return names.map { NSNumber(value: RUAEnumerationHelper.ruaParameter_(toEnumeration: $0).rawValue) }
    }

    func loadDictionaryFromDefaultsJSON() -> [String: Any] {
        (UserDefaults.standard.object(forKey: "storedJSON") as? [String: Any]) ?? [:]
    }

    func getEMVTransactionDataParameters(_ aidValue: String?) -> [NSNumber: Any] {
        var params: [NSNumber: Any] = [:]
        let jsonDict = loadDictionaryFromDefaultsJSON()
        if let parsed = jsonDict["RP450EMVTransactionDataParameters"] as? [String: Any] {
            for (key, value) in parsed {
                let enumKey = NSNumber(value: RUAEnumerationHelper.ruaParameter_(toEnumeration: key).rawValue)
                params[enumKey] = value
            }
        }
        return params
    }
}

// MARK: - Error Handling

extension IngenicoDeviceManager {

    func handleRuaResponseError(_ response: RUAResponse) {
        os_log("RUA ERROR:: %@", ruaResponse(toString: response))

        let error = NSError(
            domain: ingenicoErrorDomain,
            code: Int(response.errorCode.rawValue),
            userInfo: [
                NSLocalizedDescriptionKey: NSLocalizedString("Terminal configuration error",
                                                              comment: "Terminal configuration error"),
                NSDebugDescriptionErrorKey: ruaResponse(toString: response)
            ]
        )

        switch response.command {
        case .commandEMVStartTransaction:
            handleEmvStartTransactionError(response)
        case .commandEMVCompleteTransaction:
            handleCompleteTransactionError(response)
        default:
            if response.errorCode == RUAErrorCodeDOLNotConfigured {
                delegate?.onDeviceConfigurationProgress(100, total: 100, isFailed: true)
            } else {
                delegate?.transactionError(error)
            }
        }

        if response.errorCode == RUAErrorCodeDOLNotConfigured {
            configuredDevices.removeAll()
            saveConfiguredDevices()
            deviceManager?.getConfigurationManager().sendRawCommand(
                ruaDeviceHardResetPayload,
                progress: progressResponse ?? noopProgress,
                response: { _ in }
            )
        }
    }

    func handleEmvStartTransactionError(_ response: RUAResponse) {
        updateTransactionAfterCompleteTransactionResponse(response)
        var error: NSError?

        switch response.errorCode {
        case RUAErrorCodeApplicationBlocked:
            error = NSError(domain: ingenicoErrorDomain, code: 200,
                            userInfo: [NSLocalizedDescriptionKey:
                                NSLocalizedString("sh_application_blocked", comment: "Application Blocked")])
        case RUAErrorCodeCardInterfaceGeneralError:
            error = NSError(domain: ingenicoErrorDomain, code: 200,
                            userInfo: [NSLocalizedDescriptionKey:
                                NSLocalizedString("sh_card_interface_general_error", comment: "Card Interface General Error")])
        case RUAErrorCodeNoMutuallySupportedAIDs:
            delegate?.onTransactionStatus(.unknownAID, withIngenicoResponse: nil)
            restartTransactionAfterDelay(3)
            return
        case RUAErrorCodeTimeoutExpired:
            error = NSError(domain: ingenicoErrorDomain, code: 200,
                            userInfo: [NSLocalizedDescriptionKey:
                                NSLocalizedString("sh_timeout_expired", comment: "Timeout Expired")])
        case RUAErrorCodeNonEMVCardOrCardError:
            delegate?.onTransactionStatus(.notAcceptedRemoveCard, withIngenicoResponse: nil)
        case RUAErrorCodeCardBlocked:
            delegate?.onTransactionStatus(.cardBlocked, withIngenicoResponse: nil)
        case RUAErrorCodeBatteryTooLowError:
            delegate?.deviceError(NSError(domain: ingenicoErrorDomain, code: 200,
                                          userInfo: [NSLocalizedDescriptionKey:
                                              NSLocalizedString("sh_terminal_battery_low",
                                                                comment: "Terminal battery too low")]))
        case RUAErrorCodeCommandCancelledUponReceiptOfACancelWaitCommand:
            break
        default:
            error = NSError(domain: ingenicoErrorDomain, code: 200,
                            userInfo: [NSLocalizedDescriptionKey:
                                NSLocalizedString("sh_general_error", comment: "General Error")])
        }

        if let error = error { delegate?.transactionError(error) }
    }

    func handleCompleteTransactionError(_ response: RUAResponse) {
        if transactionStatus == .onlineApproved || transactionStatus == .hostTimeout {
            terminalTender?.voidReason        = .chipDeclined
            terminalTender?.transactionResult = .reversalRequired
            terminalTender?.transactionType   = .void
            delegate?.onTransactionStatus(.reversalRequested, withIngenicoResponse: terminalTender)
        } else {
            let error: NSError
            switch response.errorCode {
            case RUAErrorCodeNonEMVCardOrCardError:
                error = NSError(domain: ingenicoErrorDomain, code: 200,
                                userInfo: [NSLocalizedDescriptionKey:
                                    NSLocalizedString("EMV response error or missing values",
                                                      comment: "EMV response error or missing values")])
            default:
                error = NSError(domain: ingenicoErrorDomain, code: 200,
                                userInfo: [NSLocalizedDescriptionKey:
                                    NSLocalizedString("Card Interface General Error",
                                                      comment: "Card Interface General Error")])
            }
            delegate?.transactionError(error)
        }
    }
}

// MARK: - Logging Helpers

extension IngenicoDeviceManager {

    func ruaResponse(toString response: RUAResponse) -> String {
        var result = ""
        result += "\(RUAEnumerationHelper.ruaParameter_(toString: .command) ?? ""):\(RUAEnumerationHelper.ruaCommand_(toString: response.command) ?? ""),\n"
        result += "\(RUAEnumerationHelper.ruaParameter_(toString: .responseCode) ?? ""):\(RUAEnumerationHelper.ruaResponseCode_(toString: response.responseCode) ?? ""),\n"
        result += "\(RUAEnumerationHelper.ruaParameter_(toString: .responseType) ?? ""):\(RUAEnumerationHelper.ruaResponseType_(toString: response.responseType) ?? ""),\n"

        if response.responseCode == RUAResponseCodeError {
            result += "\(RUAEnumerationHelper.ruaParameter_(toString: .errorCode) ?? ""):\(RUAEnumerationHelper.ruaErrorCode_(toString: response.errorCode) ?? ""),\n"
            if let details = response.additionalErrorDetails {
                result += "\(RUAEnumerationHelper.ruaParameter_(toString: .errorDetails) ?? ""):\(details),\n"
            }
        }

        if let responseData = response.responseData as? [NSNumber: Any] {
            for (key, value) in responseData {
                if let param = RUAParameter(rawValue: key.intValue) {
                    result += "\(RUAEnumerationHelper.ruaParameter_(toString: param) ?? ""):\(value),\n"
                }
            }
        }
        return result
    }

    func logRuaParamDictionary(_ dictionary: [NSNumber: Any]?) {
        guard let dictionary = dictionary else { return }
        var output = ""
        for (key, value) in dictionary {
            if let param = RUAParameter(rawValue: key.intValue) {
                output += "\(RUAEnumerationHelper.ruaParameter_(toString: param) ?? ""):\(value),\n"
            }
        }
        os_log("%@", output)
    }
}

// MARK: - Paired Devices Persistence

extension IngenicoDeviceManager {

    func savePairedDevices() {
        let archiveArray: [Data] = pairedDevices.compactMap {
            try? NSKeyedArchiver.archivedData(withRootObject: $0, requiringSecureCoding: false)
        }
        UserDefaults.standard.set(archiveArray, forKey: pairedDeviceKey)
        UserDefaults.standard.synchronize()
        pairedDevices.removeAll()
    }
}

// MARK: - RUADeviceSearchListener

extension IngenicoDeviceManager: RUADeviceSearchListener {

    func discoveredDevice(_ reader: RUADevice!) {
        guard reader?.name != nil else { return }
        discoveredDevices.append(reader)
    }

    func discoveryComplete() {
        let deviceList = discoveredDevices.map { Device(withName: $0.name, identifier: $0.identifier) }
        delegate?.devicesFound(deviceList)
    }
}

// MARK: - RUADeviceStatusHandler

extension IngenicoDeviceManager: RUADeviceStatusHandler {

    func onConnected() {
        if let selected = selectedRUADevice {
            let alreadyPaired = pairedDevices.contains { $0.name == selected.name }
            if !alreadyPaired {
                pairedDevices.append(selected)
                savePairedDevices()
            }
        }
        onDeviceConnected()
    }

    func onDisconnected() {
        delegate?.deviceDisconnected()
    }

    func onError(_ message: String!) {
        delegate?.deviceError(NSError(
            domain: ingenicoErrorDomain, code: 200,
            userInfo: [NSLocalizedDescriptionKey:
                "Selected device failed to connect or bluetooth is not supported"]
        ))
    }
}

// MARK: - RUAPairingListener

extension IngenicoDeviceManager: RUAPairingListener {

    func onPairFailed() {
        os_log("RUAAudioJackPairingListener:- onPairFailed")
    }

    func onPairNotSupported() {
        os_log("RUAAudioJackPairingListener:- onPairNotSupported")
    }

    func onPairSucceeded() {
        os_log("RUAAudioJackPairingListener:- onPairSucceeded")
    }
}

// MARK: - RUAReleaseHandler

extension IngenicoDeviceManager: RUAReleaseHandler {

    func done() {
        // Add implementation if required
    }
}
