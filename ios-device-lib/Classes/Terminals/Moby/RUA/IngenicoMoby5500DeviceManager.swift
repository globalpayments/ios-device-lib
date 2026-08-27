//
//  IngenicoMoby5500DeviceManager.swift
//  ios-device-lib
//

import Foundation
import os.log
import MediaPlayer
import ExternalAccessory
import AVFoundation
import UIKit

// MARK: - Private Constants

private let pairedDeviceKey         = "PairedDevices"
private let ingenicoErrorDomain     = "com.heartland.Heartland-iOS-SDK.ingenico"
private let ruaDeviceHardResetPayload = "FF880A0000"
private let insertICCOnly           = "C00C"
private let configuredDeviceKey     = "ConfiguredDevices"
private let kMaxRetries             = 2

// MARK: - IngenicoMoby5500DeviceManager

@objcMembers
public class IngenicoMoby5500DeviceManager: NSObject, ConnectionListener {
    
    

    // MARK: - Properties

    var deviceManager: RUADeviceManager?
    var configManager: RUAConfigurationManager?
    var transactionManager: RUATransactionManager?
    var selectedRUADevice: RUADevice?
    var deviceType: RUADeviceType = RUADeviceTypeMOBY5500
    var discoveredDevices: [RUADevice] = []
    var pairedDevices: [RUADevice] = []
    var configuredDevices: Set<String> = []
    var terminalTender: TerminalTender?

    var configuration: IngenicoDeviceConfiguration?
    var configurationProgress: Int = 0
    var configurationStepCount: Int = 0
    weak var delegate: IngenicoDeviceManagerDelegate?
    var emvConfiguration: EMVTerminalConfiguration?
    var currentPublicKeyIndex: Int = 0
    var deviceSerialNumber: String?
    var kernelVersionNumber: String?
    var aids: [AID]?
    var aidValue: String?
    var dipCount: Int = 0
    var fallbackRequested: Bool = false
    var inPairingFlow: Bool = false
    var initialized: Bool = false
    var didntPushYet: Bool = false
    var debug: Bool = false
    var autoConnectReader: Bool = false
    var transactionStatus: TransactionStatus = .offlineDecline
    var log: OSLog!

    var progressResponse: ((RUAProgressMessage, String?) -> Void)?
    var progressHandler: (RUAProgressMessage, String?) -> Void {
        return progressResponse ?? { _, _ in }
    }
    var handleSerialNumberResponse: ((RUAResponse) -> Void)?
    var connectedDeviceSerialNumber: String?

    var selectedDevice: RUADevice?
    var isUserInitiatedDisconnect: Bool = false
    var isSilentRelease: Bool = false
    var pendingReconnect: Bool = false
    var retryCount: Int = 0
    var isUSBSearchForMOBY5500: Bool = false

    // LED pairing callback (replaces the static ivar)
    var ledConfirmationMoby5500Cb: RUALedPairingConfirmationCallback?
    var connectionInterface: RUACommunicationInterface? = RUACommunicationInterfaceBluetooth
    private var connectingFinishBlock: ((Bool?) -> Void) = {_ in }
    
    // MARK: - Init
    
    required public init(config terminalConfig: RUATerminalConfig,
                autoConnect: Bool,
                delegate: IngenicoDeviceManagerDelegate) {

        super.init()

        self.debug       = terminalConfig.isDebug
        self.delegate    = delegate
        self.deviceType  = IngenicoMoby5500DeviceManager.ruaDeviceType(from: terminalConfig.terminalType)
        self.deviceManager  = RUA.getDeviceManager(deviceType)
        self.configManager  = deviceManager?.getConfigurationManager()
        self.configManager?.setCommandTimeout(30000)
        self.didntPushYet   = false
        self.connectionInterface = terminalConfig.connectionInterface

        EAAccessoryManager.shared().registerForLocalNotifications()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(eaDeviceConnected(_:)),
            name: .EAAccessoryDidConnect,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(eaDeviceDisconnect(_:)),
            name: .EAAccessoryDidDisconnect,
            object: nil
        )

        RUA.setProductionMode(terminalConfig.isProduction)
        RUA.enableDebugLogMessages(debug)
        discoveredDevices     = []
        pairedDevices         = []
        currentPublicKeyIndex = 0
        configuredDevices     = []
        
        self.configuration = IngenicoDeviceConfiguration(
            productionMode: !debug,
            deviceType: RUAMobyDeviceType(rawValue: Int(deviceType.rawValue)) ?? .MOBY5500
        )

        if autoConnect {
            initializeDevice()
        }

        _ = loadDictionaryFromJSON()
        _ = fetchAndStoreJSON()
        fetchAndUpdateEMVTransactionConfigsJSON()
    }

    deinit {
        EAAccessoryManager.shared().unregisterForLocalNotifications()
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Static Helpers

private extension IngenicoMoby5500DeviceManager {

    static func ruaDeviceType(from type: RUATerminalType) -> RUADeviceType {
        switch type {
        case .rp450c:    return RUADeviceTypeRP450c
        case .rp350x:    return RUADeviceType(rawValue: 1)  // RUADeviceTypeRP350x (deprecated)
        case .g4x_g5x:   return RUADeviceType(rawValue: 0)  // RUADeviceTypeG4x (deprecated)
        case .rp45BT:    return RUADeviceTypeRP45BT
        case .moby3000:  return RUADeviceTypeMOBY3000
        case .moby8500:  return RUADeviceTypeMOBY8500
        case .moby5500:  return RUADeviceTypeMOBY5500
        default:         return RUADeviceTypeRP450c
        }
    }

    static func cardDataSourceType(_ type: String?) -> CardDataSource {
        guard let type = type else { return .swipe }
        switch type {
        case "91":        return .nfc
        case "02", "90":  return .swipe
        case "07":        return .emvContactless
        case "05", "95":  return .emv
        case "00":        return .emv
        default:          return .none
        }
    }
}

// MARK: - EA Accessory / Device Lifecycle

extension IngenicoMoby5500DeviceManager {

    func eaDeviceConnected(_ notification: Notification) {
        
        if self.connectionInterface == RUACommunicationInterfaceUSB {
            if let accessory = notification.userInfo?[EAAccessoryKey] as? EAAccessory {
                os_log("EA Accessory connected: %@ protocols: %@", accessory.name, accessory.protocolStrings)
                os_log("MFI accessory connected: %@ protocols: %@", accessory.name, accessory.protocolStrings.joined(separator: ", "))
                // If MOBY5500 is the selected device type, begin initialization as soon as the cable is plugged in
                if self.deviceType == RUADeviceTypeMOBY5500 && deviceManager != nil {
                    DispatchQueue.main.async {
                        os_log("MOBY5500: MFI accessory detected — starting initialization...")
                        self.initializeDevice()
                    }
                }
            }
        } else {
            guard !inPairingFlow, autoConnectReader else { return }
            guard let userInfo = notification.userInfo,
                  let accessory = userInfo[EAAccessoryKey] as? EAAccessory else { return }
            let protocols = ["com.landicorp.datapath", "com.landi.datapath"]
            if accessory.protocolStrings.contains(where: { protocols.contains($0) }) {
                deviceManager?.initializeDevice(self)
            }
        }
    }

    func eaDeviceDisconnect(_ notification: Notification) {
        if self.connectionInterface == RUACommunicationInterfaceUSB {
            if let accessory = notification.userInfo?[EAAccessoryKey] as? EAAccessory {
                os_log("EA Accessory disconnected: %@", accessory.name)
            }
        }
    }
    
    func initializeDevice() {
        guard isBluetoothSupported() else {
            delegate?.deviceError(NSError(
                domain: ingenicoErrorDomain, code: 200,
                userInfo: [NSLocalizedDescriptionKey:
                    "Selected device failed to connect or bluetooth is not supported"]
            ))
            return
        }
        
        guard let selectedDevice = selectedRUADevice else {
            os_log("MOBY5500: No device selected — ensure device is plugged in and search first.")
            return
        }
        print("Initialize Reader \(selectedDevice.name ?? ""), interface=\(selectedDevice.communicationInterface)")
        configManager?.activate(selectedDevice)
        
        if connectionInterface == RUACommunicationInterfaceUSB {
            var filename: String
            filename = "provisioning_5500"
            
            let resourceBundle = Bundle(for: type(of: self))
            guard let provisioningFilePath = resourceBundle.path(forResource: filename, ofType: "json"),
                  let content = try? String(contentsOfFile: provisioningFilePath, encoding: .utf8) else {
                os_log("Failed to load provisioning file: %@", "\(filename).json")
                return
            }
            os_log("Initializing with provisioning file: %@", provisioningFilePath)
            // MOBY5500 firmware v1.1.1 rejects auto JSON provisioning (error 8E07 — firmware version mismatch).
            // Disable auto-provisioning for MOBY5500 to avoid the spurious "Provisioning pushing failed" error.
            let autoProvision = self.deviceType != RUADeviceTypeMOBY5500
            let initialized = deviceManager?.initializeDevice(
                self,
                andTimeout: 0,
                andJsonContent: content,
                andAutoJsonProvisioning: autoProvision
            )
            
            if initialized != nil {
                os_log("initializeDevice started — waiting for onConnected...")
                deviceManager?.getConfigurationManager().setCommandTimeout(60)
            } else {
                os_log("initializeDevice failed to start — check device type and connection.")
            }
        } else {
            deviceManager?.initializeDevice(self, pairingListener: self)
        }
    }

    func isBluetoothSupported() -> Bool {
        return deviceManager?.getType() == RUADeviceTypeMOBY5500
    }

    // Internal – dispatches SDK calls onto the BLE thread.
    func _initializeDevice() {
        bleDispatch { [weak self] in
            guard let self = self else { return }
            if let selectDevice = self.selectedDevice {
                self.configManager?.activate(selectDevice)
            }
            self.deviceManager?.initializeDevice(self, pairingListener: self)
        }
    }
}

// MARK: - IngenicoMethods: Scan / Connect / Disconnect

extension IngenicoMoby5500DeviceManager: IngenicoMethods {

    
    public func scanForDevices() {
        deviceManager = RUA.getDeviceManager(deviceType)
        configManager = deviceManager?.getConfigurationManager()
        discoveredDevices.removeAll()

        if !discoveredDevices.isEmpty {
            discoveredDevices.removeAll()
        }
        bleDispatch { [weak self] in
            guard let self = self else { return }
            self.deviceManager?.searchDevices(self)
        }
    }

    public func cancelSearch() {
        deviceManager?.cancelSearch()
    }

    public func connect(_ device: Device) {
        guard let connectionInterface else { return }
        
        if self.connectionInterface == RUACommunicationInterfaceUSB {
            let landiProtocols: Set<String> = [
                "com.landicorp.USBdatapath",
                "com.landicorp.datapath",
                "com.landi.datapath"
            ]
            EAAccessoryManager.shared().connectedAccessories
                .filter { $0.protocolStrings.contains(where: { landiProtocols.contains($0) }) }
                .forEach { accessory in
                    let ruaDevice = RUADevice(
                        name: accessory.name,
                        withIdentifier: accessory.serialNumber,
                        with: RUACommunicationInterfaceUSB
                    )
                    guard let device = ruaDevice else { return }
                    print("MOBY5500: EA connected accessories: device interface:", accessory.name, device.communicationInterface)
                }
            
            os_log("MOBY5500: Starting USB-only device search...")
            
            isUSBSearchForMOBY5500 = true
            selectedDevice = nil
            discoveredDevices = []
            
            os_log("Searching (USB)")
            let usbInterface: [NSNumber] = [NSNumber(value: RUACommunicationInterfaceUSB.rawValue)]
            self.deviceManager?.searchDevices(
                withLowRSSI: -100,
                andHighRSSI: 0,
                andDuration: 5000,
                andCommunicationInterfaces: usbInterface,
                andListener: self
            )
            os_log("Start USB pairing...")
        } else {
            let terminal = RUADevice(
                name: device.name,
                withIdentifier: device.identifier,
                with: connectionInterface
            )
            selectedRUADevice = terminal
            initializeDevice()
        }
    }

    /// BLE-specific connect – builds device then calls _initializeDevice.
    func connectToDevice(_ device: RUADevice) {
        selectedDevice = RUADevice(
            name: device.name,
            withIdentifier: device.identifier,
            with: RUACommunicationInterfaceBluetooth
        )
        isUserInitiatedDisconnect = false
        retryCount = 0
        _initializeDevice()
    }

    public func disconnect() {
        isUserInitiatedDisconnect = true
        retryCount = 0
        if deviceManager != nil {
            bleDispatch { [weak self] in
                guard let self = self else { return }
                self.deviceManager?.releaseDevice(self)
            }
        }
    }

    public func batteryLevel() {
        // FIXME: Complete implementation
    }

    public func startWithTender(_ tender: TerminalTender) {
        terminalTender = tender
        if debug {
            os_log("%d", tender.amount)
        }

        if let isReady = deviceManager?.isReady, !isReady() {
            initializeDevice()
        }

        fallbackRequested = false
        dipCount = 0
        terminalTender = tender

        setupAIDSandPublicKeys()
    }

    public func confirmAmount(_ confirmed: Bool) {
        if confirmed {
            if let isChip = terminalTender?.isChipTransaction(),
               !isChip {
                deviceManager?.getTransactionManager().send(
                    .commandEMVTransactionStop,
                    withParameters: nil,
                    progress: progressHandler
                ) { [weak self] _ in
                    guard let self = self else { return }
                    self.delegate?.onTransactionStatus(.goOnlineRequested,
                                                       withIngenicoResponse: self.terminalTender)
                }
            } else if terminalTender?.cardDataSource == .emvContactless {
                // TODO: (scheduled) Contactless feature
            } else {
                sendEMVTransactionDataCommandWithAID(aidValue)
            }
        } else {
            cancelTransaction()
        }
    }
    
    public func selectedAID(_ aid: AID) {
        // Send EMV Transaction Data command with selected AID
    }
    
    public func sendOnlineProcessingResult(_ onlineResult: HostTenderResponse) {
        transactionStatus = onlineResult.transactionStatus

        var params: [NSNumber: Any] = [:]
        var hexString = "303030303030"
        let authCode = onlineResult.gatewayAuthCode

        if let authCode = authCode, !authCode.isEmpty {
            //hexString = TLVUtility.dataToHexString(authCode.data(using: .utf8))
            if let authCode = authCode.data(using: .utf8), let hex = TLVUtility.dataToHexString(authCode) {
                hexString = hex
            }
        }

        params[NSNumber(value: RUAParameter.authorizationCode.rawValue)]             = hexString
        params[NSNumber(value: RUAParameter.resultofOnlineProcess.rawValue)]         = onlineResult.onlineProcessResult
        params[NSNumber(value: RUAParameter.authorizationResponseCode.rawValue)]     = onlineResult.emvIssuerAuthCode
        params[NSNumber(value: RUAParameter.authorizationResponseCodeList.rawValue)] = "59315A3159325A3259335A333030303530313034"

        if onlineResult.tender?.transactionType == .sale ||
           onlineResult.tender?.transactionType == .auth {
            if let data = onlineResult.emvIssuerAuthenticationData, !data.isEmpty {
                params[NSNumber(value: RUAParameter.issuerAuthenticationData.rawValue)] =
                    TLVUtility.tagValue(fromTLV: data)
            }
            if let scripts = onlineResult.emvIssuerScripts, !scripts.isEmpty {
                let tags = TLVGMParser.splitTLVData(scripts)
                for tag in tags ?? [] {
                    if TLVGMParser.isIssuerScriptTemplate1(tag) {
                        params[NSNumber(value: RUAParameter.issuerScript1.rawValue)] =
                            TLVUtility.tagValue(fromTLV: tag)
                    } else if TLVGMParser.isIssuerScriptTemplate2(tag) {
                        params[NSNumber(value: RUAParameter.issuerScript2.rawValue)] =
                            TLVUtility.tagValue(fromTLV: tag)
                    }
                }
            }
        }

        if debug {
            os_log("HostTenderResponse %@", params)
        }

        transactionManager?.send(
            .commandEMVTransactionStop,
            withParameters: nil,
            progress: { [weak self] messageType, _ in
                self?.consoleLog(RUAEnumerationHelper.ruaProgressMessage_(toString: messageType))
            }
        ) { [weak self] ruaResponse in
            guard let self = self, let ruaResponse = ruaResponse else { return }
            self.consoleLog(self.ruaResponse(toString: ruaResponse))
            self.handleCompleteTransactionResponse(ruaResponse, andOnlineResult: onlineResult)
        }
    }

    public func cancelTransaction() {
        transactionManager?.send(
            .commandEMVTransactionStop,
            withParameters: nil,
            progress: progressHandler
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
    
    func reconnectLastDevice(connectingFinishBlock : @escaping (Bool?) -> Void) {
        guard let saved = lastSelectedDevice() else { return connectingFinishBlock(false) }
        selectedDevice = saved
        isUserInitiatedDisconnect = false
        retryCount = 0
        _initializeDevice()   // BLE thread, no scan
        self.connectingFinishBlock = connectingFinishBlock
    }
    
    func hasSavedDevice() -> Bool {
        return lastSelectedDevice() != nil
    }
}

// MARK: - RUADeviceSearchListener

extension IngenicoMoby5500DeviceManager: RUADeviceSearchListener {

    public func discoveredDevice(_ reader: RUADevice!) {
        os_log("discoveredDevice: %@", reader?.name ?? "No device")
        if let name = reader?.name, !name.isEmpty {
            os_log("[BLE] Found: %@, %d", name, (reader?.rssIvalue ?? 0))
        }
        if let reader = reader, reader.name != nil {
            discoveredDevices.append(reader)
        }
        if isUSBSearchForMOBY5500 {
            if discoveredDevices.count > 0 {
                selectedRUADevice  = discoveredDevices.first
                os_log("MOBY5500 USB device found: %@ (interface:%d) — initializing...", selectedRUADevice?.name ?? "", selectedRUADevice?.identifier ?? "")
                initializeDevice()
            } else {
                os_log("MOBY5500: No USB device found. Ensure the USB-C cable is connected and the device is powered on.")
            }
        }
    }

    public func discoveryComplete() {
        os_log("[BLE] Scan complete")
        let deviceList: [Device] = discoveredDevices.map {
            Device(withName: $0.name, identifier: $0.identifier)
        }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.devicesFound(deviceList)
        }
        if isUSBSearchForMOBY5500 {
            isUSBSearchForMOBY5500 = false
            if discoveredDevices.count > 0 {
                selectedRUADevice  = discoveredDevices.first
                os_log("MOBY5500 USB device found: %@ (interface:%d) — initializing...", selectedRUADevice?.name ?? "", selectedRUADevice?.identifier ?? "")
                initializeDevice()
            } else {
                os_log("MOBY5500: No USB device found. Ensure the USB-C cable is connected and the device is powered on.")
            }
        }
    }
}

// MARK: - RUADeviceStatusHandler (Connection Callbacks)

extension IngenicoMoby5500DeviceManager: RUADeviceStatusHandler {

    public func onConnected() {
        os_log("[BLE] onConnected — %@", selectedRUADevice?.name ?? "")
        self.connectingFinishBlock(true)
        
        if let device = self.selectedDevice ?? self.selectedRUADevice {
            saveSelectedDevice(device)
        }
        let tmgr = deviceManager?.getTransactionManager()
        if let tmgr = tmgr {
            tmgr.send(.commandEMVTransactionStop,
                      withParameters: nil,
                      progress: { _, _ in }) { [weak self] _ in
                self?.fetchCapabilities()
            }
            configManager?.stopLogRecord(viaUSB: { response in
                os_log("%@", response ?? "")
            })
        } else {
            fetchCapabilities()
        }
    }

    public func onDisconnected() {
        os_log("[BLE] onDisconnected (user-initiated: %d)", isUserInitiatedDisconnect ? 1 : 0)
        clearSavedDevice()
        connectingFinishBlock(false)
        if !isUserInitiatedDisconnect, selectedDevice != nil {
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 1) { [weak self] in
                guard let self = self else { return }
                self.retryCount = 0
            }
            return
        }
        isUserInitiatedDisconnect = false
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.deviceDisconnected()
        }
    }

    public func onError(_ message: String!) {
        os_log("[BLE] onError: %@", message ?? "")
        selectedDevice = nil
        bleDispatch { [weak self] in
            guard let self = self else { return }
            self.deviceManager?.releaseDevice(self)
        }
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.deviceError(NSError(
                domain: "Moby5500", code: -1,
                userInfo: [NSLocalizedDescriptionKey: message ?? "BLE error"]
            ))
        }
    }

    public func onPlugged() {
        os_log("Device Plugged")
        os_log("MOBY5500 USB plugged in — starting initialization...")
        if isBluetoothSupported() {
            initializeDevice()
        }
    }
    
    public func onDeviceConnectionFailed() {
        os_log("[BLE] onDeviceConnectionFailed (retry %d/%d)", retryCount, kMaxRetries)
        scheduleRetryOrFail()
    }

    public func onDeviceConnectionCancelled() {
        if isSilentRelease { return }
        if isUserInitiatedDisconnect {
            isUserInitiatedDisconnect = false
            selectedDevice = nil
            DispatchQueue.main.async { [weak self] in
                self?.delegate?.deviceDisconnected()
            }
            return
        }
        scheduleRetryOrFail()
    }

    // MARK: Private helpers

    private func fetchCapabilities() {
        configManager?.getReaderCapabilities({ _, _ in }) { [weak self] response in
            guard let self = self, let response = response else { return }
            if response.responseCode == RUAResponseCodeSuccess {
                let serial = response.responseData?[
                    NSNumber(value: RUAParameter.interfaceDeviceSerialNumber.rawValue)] as? String
                os_log("[BLE] Serial: %@", serial ?? "")
            }
            DispatchQueue.main.async {
                self.delegate?.deviceConnected()
            }
        }
    }

    private func scheduleRetryOrFail() {
        if retryCount < kMaxRetries, selectedDevice != nil {
            retryCount += 1
            os_log("[BLE] Scheduling retry %d/%d", retryCount, kMaxRetries)
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 1.5) { [weak self] in
                guard let self = self, self.selectedDevice != nil else { return }
                self.isSilentRelease  = true
                self.pendingReconnect = true
                bleDispatch { self.deviceManager?.releaseDevice(self) }
            }
        } else {
            retryCount = 0
            selectedDevice = nil
            DispatchQueue.main.async { [weak self] in
                self?.delegate?.deviceError(NSError(
                    domain: "Moby5500", code: 202,
                    userInfo: [NSLocalizedDescriptionKey: "Connection failed after all retries."]
                ))
            }
        }
    }
}

// MARK: - RUAReleaseHandler

extension IngenicoMoby5500DeviceManager: RUAReleaseHandler {

    public func done() {
        isSilentRelease = false
        if pendingReconnect, selectedDevice != nil {
            pendingReconnect = false
            os_log("[BLE] done — SDK clean, reinitializing (retry %d/%d)", retryCount, kMaxRetries)
            bleDispatch { [weak self] in
                guard let self = self else { return }
                if let dev = self.selectedDevice {
                    self.configManager?.activate(dev)
                }
                self.deviceManager?.initializeDevice(self, pairingListener: self)
            }
        }
    }
}

// MARK: - RUAPairingListener

extension IngenicoMoby5500DeviceManager: RUAPairingListener {

    public func onPairSucceeded() {
        os_log("[BLE] Pairing succeeded")
    }

    public func onPairFailed() {
        os_log("[BLE] Pairing failed")
    }

    public func onPairCancelled() {
        os_log("[BLE] Pairing cancelled")
    }

    public func onPairNotSupported() {
        os_log("[BLE] Pairing not supported")
    }
}

// MARK: - RUAAudioJackPairingListener (LED Pairing UI)

extension IngenicoMoby5500DeviceManager: RUAAudioJackPairingListener {

    public func onLedPairSequenceConfirmation(
        _ ledSequence: [Any],
        confirmationCallback callback: RUALedPairingConfirmationCallback
    ) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.ledConfirmationMoby5500Cb = callback

            let bundle = Bundle(for: IngenicoMoby5500DeviceManager.self)
            let sb = UIStoryboard(name: "RuaPairingStoryBoard", bundle: bundle)
            guard let pairingView = sb.instantiateViewController(
                withIdentifier: "PairingViewController") as? PairingViewController else {
                os_log("[Pairing] Could not instantiate PairingViewController from storyboard in bundle: %@",
                       bundle.bundlePath)
                return
            }

            guard let ruaDevice = self.selectedDevice ?? self.selectedRUADevice else {
                os_log("[Pairing] No selected device — cannot present PairingViewController")
                return
            }
            pairingView.selectedDevice = ruaDevice
            pairingView.delegate       = self
            pairingView.setLedConfirmationCB(callback)

            guard let root = self.topmostViewController() else {
                os_log("[Pairing] No root view controller — cannot present PairingViewController")
                return
            }

            root.present(pairingView, animated: true) {
                pairingView.showPairingView(sequences: ledSequence)
            }
        }
    }
    
    private func keyWindow() -> UIWindow? {
        if #available(iOS 15.0, *) {
            return UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }
        } else {
            return UIApplication.shared.windows.first { $0.isKeyWindow }
        }
    }

    private func topmostViewController() -> UIViewController? {
        guard var top = keyWindow()?.rootViewController else { return nil }
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }
}

// MARK: - Transaction Processing

extension IngenicoMoby5500DeviceManager {

    func startTransactionProcess() {
        transactionManager = deviceManager?.getTransactionManager()
        saveConnectedDeviceSerialNumber(connectedDeviceSerialNumber)

        let amount = String(terminalTender?.amount ?? 0)
        let parameters = getEMVStartTransactionParameters(amount)

        transactionManager?.send(
            .commandEMVStartTransaction,
            withParameters: parameters,
            progress: { [weak self] messageType, _ in
                self?.consoleLog(RUAEnumerationHelper.ruaProgressMessage_(toString: messageType))
            }
        ) { [weak self] ruaResponse in
            guard let self = self, let ruaResponse = ruaResponse else { return }
            self.consoleLog(self.ruaResponse(toString: ruaResponse))
            if ruaResponse.responseCode == RUAResponseCodeSuccess {
                self.handleEmvStartTransactionResponse(ruaResponse)
            } else {
                self.handleRuaResponseError(ruaResponse)
            }
        }
    }

    func handleEmvStartTransactionResponse(_ response: RUAResponse) {
        let responseType = response.responseType
        let cidValue = response.responseData?[NSNumber(value: RUAParameter.cryptogramInformationData.rawValue)] as? String
        let paypassOutcome = (response.responseData?[NSNumber(value: RUAParameter.payPassTransactionOutcome.rawValue)] as? String).flatMap {
            $0.count >= 2 ? String($0.prefix(2)) : nil
        }
        let terminalDecision = response.responseData?[NSNumber(value: RUAParameter.terminalDecisionafterGenerateAC.rawValue)] as? String
        aidValue = response.responseData?[NSNumber(value: RUAParameter.applicationIdentifier.rawValue)] as? String

        updateTransactionAfterTransactionDataResponse(response)

        switch responseType {
        case RUAResponseTypeMagneticCardData:
            deviceManager?.getTransactionManager().send(
                .commandEMVTransactionStop,
                withParameters: nil,
                progress: progressHandler
            ) { [weak self] _ in
                self?.delegate?.onTransactionStatus(.goOnlineRequested,
                                                    withIngenicoResponse: self?.terminalTender)
            }

        case RUAResponseTypeContactEMVAmountDOL:
            sendEMVTransactionDataCommand()

        case RUAResponseTypeContactLessEMVResponseDOL:
            break // TODO: (Scheduled) Complete later

        case RUAResponseTypeContactQuickChipEMVResponseDOL:
            if paypassOutcome == "03" || paypassOutcome == "04" {
                sendEMVTransactionStopCommand()
            } else {
                checkCID(cidValue, andTerminalDecisionAfterGenerateAC: terminalDecision)
            }

        case RUAResponseTypeContactEMVOnlineDOL, RUAResponseTypeContactLessEMVOnlineDOL:
            delegate?.onTransactionStatus(.goOnlineRequested, withIngenicoResponse: terminalTender)

        case RUAResponseTypeListOfApplicationIdentifiers:
            handleListOfAidsResponse(response)

        default:
            sendEMVTransactionDataCommandWithAID(cidValue)
        }
    }

    func handleMsrResponse(_ response: RUAResponse) {
        if response.responseCode != RUAResponseCodeSuccess {
            delegate?.onTransactionStatus(.swipeErrorReswipe, withIngenicoResponse: nil)
        } else {
            aidValue = response.responseData?[NSNumber(value: RUAParameter.applicationIdentifier.rawValue)] as? String
            updateTransactionAfterTransactionDataResponse(response)
            deviceManager?.getTransactionManager().send(
                .commandEMVTransactionStop,
                withParameters: nil,
                progress: progressHandler
            ) { [weak self] _ in
                self?.delegate?.onTransactionStatus(.goOnlineRequested,
                                                    withIngenicoResponse: self?.terminalTender)
            }
        }
    }

    func handleListOfAidsResponse(_ response: RUAResponse) {
        guard let listOfAids = response.listOfApplicationIdentifiers else { return }
        var aidList: [AID] = []
        for appID in listOfAids {
            guard let appID = appID as? RUAApplicationIdentifier else { continue }
            let aid = AID()
            aid.rid = appID.rid
            aid.pix = appID.pix
            aid.applicationIdentifier = appID.aid
            aid.preferredName = appID.applicationLabel
            aidList.append(aid)
        }
        aids = aidList
        delegate?.selectAid(aids)
    }

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
            delegate?.onDeviceConfigurationProgress(100, total: 100, isFailed: true)
            cancelTransaction()
        }
    }

    func handleEmvStartTransactionError(_ response: RUAResponse) {
        let errorCode = response.errorCode
        updateTransactionAfterCompleteTransactionResponse(response)
        var error: NSError?

        switch errorCode {
        case RUAErrorCodeApplicationBlocked:
            error = NSError(domain: ingenicoErrorDomain, code: 200,
                            userInfo: [NSLocalizedDescriptionKey:
                                NSLocalizedString("sh_application_blocked",
                                                  comment: "Application Blocked")])
        case RUAErrorCodeCardInterfaceGeneralError:
            error = NSError(domain: ingenicoErrorDomain, code: 200,
                            userInfo: [NSLocalizedDescriptionKey:
                                NSLocalizedString("sh_card_interface_general_error",
                                                  comment: "Card Interface General Error")])
        case RUAErrorCodeNoMutuallySupportedAIDs:
            delegate?.onTransactionStatus(.unknownAID, withIngenicoResponse: nil)
            restartTransactionAfterDelay(3)
            return
        case RUAErrorCodeTimeoutExpired:
            error = NSError(domain: ingenicoErrorDomain, code: 200,
                            userInfo: [NSLocalizedDescriptionKey:
                                NSLocalizedString("sh_timeout_expired",
                                                  comment: "Timeout Expired")])
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
            break // Not an error — was requested
        default:
            error = NSError(domain: ingenicoErrorDomain, code: 200,
                            userInfo: [NSLocalizedDescriptionKey:
                                NSLocalizedString("sh_general_error",
                                                  comment: "General Error")])
        }

        if let error = error {
            delegate?.transactionError(error)
        }
    }

    func handleCompleteTransactionError(_ response: RUAResponse) {
        if transactionStatus == .onlineApproved || transactionStatus == .hostTimeout {
            terminalTender?.voidReason = .chipDeclined
            terminalTender?.transactionResult = .reversalRequired
            terminalTender?.transactionType   = .void
            delegate?.onTransactionStatus(.reversalRequested, withIngenicoResponse: terminalTender)
        } else {
            let errorCode = response.errorCode
            let error: NSError
            switch errorCode {
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

    func handleCompleteTransactionResponse(_ response: RUAResponse,
                                           andOnlineResult onlineResult: HostTenderResponse) {
        terminalTender?.tlvData =
            response.responseData?[NSNumber(value: RUAParameter.emvtlvData.rawValue)] as? String

        if response.responseCode == RUAResponseCodeError {
            handleRuaResponseError(response)
        } else {
            let resp = response.responseData ?? [:]
            var cidValue          = resp[NSNumber(value: RUAParameter.cryptogramInformationData.rawValue)] as? String
            var terminalDecision  = resp[NSNumber(value: RUAParameter.terminalDecisionafterGenerateAC.rawValue)] as? String

            terminalTender?.cardHolderName =
                resp[NSNumber(value: RUAParameter.cardHolderName.rawValue)] as? String

            if terminalDecision == nil || terminalDecision!.isEmpty {
                if onlineResult.transactionStatus == .onlineApproved ||
                   onlineResult.transactionStatus == .offlineApproved {
                    terminalDecision = "00"
                    cidValue         = "00"
                    terminalTender?.transactionResult = .approved
                    delegate?.onTransactionStatus(.complete, withIngenicoResponse: terminalTender)
                } else {
                    cidValue         = nil
                    terminalDecision = nil
                    terminalTender?.transactionResult = .declined
                    delegate?.onTransactionStatus(.complete, withIngenicoResponse: terminalTender)
                }
            } else {
                checkCID(cidValue, andTerminalDecisionAfterSecondGenerateAC: terminalDecision)
            }
        }
    }

    func resetDeviceManager() {
        dipCount = 0
        terminalTender = nil
    }

    func releaseDevice() {
        deviceManager?.releaseDevice(self)
    }

    func restartTransactionAfterDelay(_ delay: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(delay)) { [weak self] in
            guard let self = self, let tender = self.terminalTender else { return }
            self.startWithTender(tender)
        }
    }
}

// MARK: - EMV Command Helpers

extension IngenicoMoby5500DeviceManager {

    func sendEMVTransactionDataCommandWithAID(_ aidValue: String?) {
        let tmgr = transactionManager
        tmgr?.send(
            .commandEMVTransactionData,
            withParameters: getEMVTransactionDataParameters(aidValue),
            progress: { [weak self] messageType, _ in
                self?.consoleLog(RUAEnumerationHelper.ruaProgressMessage_(toString: messageType))
            }
        ) { [weak self] ruaResponse in
            guard let self = self, let ruaResponse = ruaResponse else { return }
            self.consoleLog(self.ruaResponse(toString: ruaResponse))
            if ruaResponse.responseCode == RUAResponseCodeSuccess {
                let cid              = ruaResponse.responseData?[NSNumber(value: RUAParameter.cryptogramInformationData.rawValue)] as? String
                self.aidValue        = cid
                let terminalDecision = ruaResponse.responseData?[NSNumber(value: RUAParameter.terminalDecisionafterGenerateAC.rawValue)] as? String
                self.checkCID(cid, andTerminalDecisionAfterGenerateAC: terminalDecision)
                self.delegate?.onTransactionStatus(.goOnlineRequested,
                                                   withIngenicoResponse: self.terminalTender)
            } else {
                self.handleRuaResponseError(ruaResponse)
                self.transactionManager?.send(
                    .commandEMVTransactionStop,
                    withParameters: nil,
                    progress: self.progressHandler
                ) { [weak self] _ in
                    self?.delegate?.onTransactionStatus(.goOnlineRequested,
                                                        withIngenicoResponse: self?.terminalTender)
                }
            }
        }
    }

    func sendEMVTransactionDataCommand() {
        transactionManager?.send(
            .commandEMVTransactionData,
            withParameters: getMoby5500EMVTransactionDataParameters(),
            progress: progressHandler
        ) { [weak self] response in
            guard let self = self, let response = response else { return }
            if response.responseCode == RUAResponseCodeSuccess {
                self.updateTransactionAfterTransactionDataResponse(response)
                let cid              = response.responseData?[NSNumber(value: RUAParameter.cryptogramInformationData.rawValue)] as? String
                let terminalDecision = response.responseData?[NSNumber(value: RUAParameter.terminalDecisionafterGenerateAC.rawValue)] as? String
                self.checkCID(cid, andTerminalDecisionAfterGenerateAC: terminalDecision)
            } else {
                self.handleRuaResponseError(response)
            }
        }
    }

    func sendEMVCompleteTransactionCommand() {
        let tmgr = transactionManager
        tmgr?.send(
            .commandEMVCompleteTransaction,
            withParameters: getEMVCompleteTransactionParameters(),
            progress: { [weak self] messageType, _ in
                self?.consoleLog(RUAEnumerationHelper.ruaProgressMessage_(toString: messageType))
            }
        ) { [weak self] ruaResponse in
            guard let self = self, let ruaResponse = ruaResponse else { return }
            self.consoleLog(self.ruaResponse(toString: ruaResponse))
            self.sendEMVTransactionStopCommand()
        }
    }

    func sendEMVTransactionStopCommand() {
        let tmgr = transactionManager
        tmgr?.send(
            .commandEMVTransactionStop,
            withParameters: nil,
            progress: { [weak self] messageType, _ in
                self?.consoleLog(RUAEnumerationHelper.ruaProgressMessage_(toString: messageType))
            }
        ) { [weak self] ruaResponse in
            guard let self = self, let ruaResponse = ruaResponse else { return }
            self.consoleLog(self.ruaResponse(toString: ruaResponse))
        }
    }
}

// MARK: - CID / Terminal Decision Checks

extension IngenicoMoby5500DeviceManager {

    func checkCID(_ cidValue: String?,
                  andTerminalDecisionAfterGenerateAC terminalDecisionValue: String?) {
        if cidValue == "00" {
            deviceManager?.getTransactionManager().send(
                .commandEMVTransactionStop,
                withParameters: nil,
                progress: progressHandler
            ) { [weak self] response in
                guard let self = self, let response = response else { return }
                self.handleCidOfflineDecline(response)
            }
        } else if cidValue == "40" {
            deviceManager?.getTransactionManager().send(
                .commandEMVTransactionStop,
                withParameters: nil,
                progress: progressHandler
            ) { [weak self] response in
                guard let self = self, let response = response else { return }
                self.handleCidOfflineApproved(response)
            }
        } else if cidValue == "80" {
            delegate?.onTransactionStatus(.goOnlineRequested, withIngenicoResponse: terminalTender)
        } else if cidValue == nil || cidValue == "" {
            checkTerminalDecisionValue(terminalDecisionValue)
        }
    }

    func checkCID(_ cidValue: String?,
                  andTerminalDecisionAfterSecondGenerateAC terminalDecisionValue: String?) {
        if cidValue == "00" || terminalDecisionValue == "00" {
            transactionManager?.send(
                .commandEMVTransactionStop,
                withParameters: nil,
                progress: progressHandler
            ) { [weak self] response in
                guard let self = self, let response = response else { return }
                if response.responseCode == RUAResponseCodeError {
                    self.handleRuaResponseError(response)
                } else {
                    if self.transactionStatus == .onlineApproved ||
                       self.transactionStatus == .hostTimeout {
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
            }
        } else if cidValue == "40" {
            transactionManager?.send(
                .commandEMVTransactionStop,
                withParameters: nil,
                progress: progressHandler
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

    func checkTerminalDecisionValue(_ terminalDecisionValue: String?) {
        if terminalDecisionValue == "01" {
            sendEMVTransactionStopCommand()
        } else if terminalDecisionValue == "00" {
            sendEMVTransactionStopCommand()
        }
    }

    func checkTerminalDecisionValueSecondGenerateAC(_ terminalDecisionValue: String?) {
        if terminalDecisionValue == "01" {
            transactionManager?.send(
                .commandEMVTransactionStop,
                withParameters: nil,
                progress: progressHandler
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
                .commandEMVTransactionStop,
                withParameters: nil,
                progress: progressHandler
            ) { [weak self] response in
                guard let self = self, let response = response else { return }
                self.handlePostAuthDecline(response)
            }
        }
    }

    func handleCidOfflineDecline(_ response: RUAResponse) {
        if response.responseCode == RUAResponseCodeError {
            handleRuaResponseError(response)
        } else {
            transactionStatus = .offlineDecline
            terminalTender?.transactionResult = .offlineDecline
            delegate?.onTransactionStatus(.complete, withIngenicoResponse: terminalTender)
        }
    }

    func handleCidOfflineApproved(_ response: RUAResponse) {
        if response.responseCode == RUAResponseCodeError {
            handleRuaResponseError(response)
        } else {
            transactionStatus = .offlineApproved
            terminalTender?.transactionResult = .offlineApproved
            delegate?.onTransactionStatus(.complete, withIngenicoResponse: terminalTender)
        }
    }

    func handlePostAuthDecline(_ response: RUAResponse) {
        if response.responseCode == RUAResponseCodeError {
            handleRuaResponseError(response)
        } else {
            if transactionStatus == .onlineApproved || transactionStatus == .hostTimeout {
                terminalTender?.transactionResult = .reversalRequired
                terminalTender?.voidReason        = .chipDeclined
                delegate?.onTransactionStatus(.reversalRequested,
                                              withIngenicoResponse: terminalTender)
            } else {
                terminalTender?.transactionResult = .postAuthChipDecline
                delegate?.onTransactionStatus(.postAuthChipDecline,
                                              withIngenicoResponse: terminalTender)
                terminalTender = nil
            }
        }
    }
}

// MARK: - Transaction Data Updates

extension IngenicoMoby5500DeviceManager {

    func updateTransactionAfterTransactionDataResponse(_ response: RUAResponse) {
        logRuaParamDictionary(response.responseData)

        let resp = response.responseData ?? [:]
        let tlvData              = resp[NSNumber(value: RUAParameter.emvtlvData.rawValue)] as? String
        let entryMode            = resp[NSNumber(value: RUAParameter.posEntryMode.rawValue)] as? String
        let packEncryptedTrackData = resp[NSNumber(value: RUAParameter.packEncryptedTrackData.rawValue)] as? String
        let cvmResult            = resp[NSNumber(value: RUAParameter.cardholderVerificationMethodResult.rawValue)] as? String

        if terminalTender == nil { terminalTender = TerminalTender() }

        if fallbackRequested {
            terminalTender?.fallbackSwipe = true
            if dipCount >= 3 {
                terminalTender?.emvFallbackCondition = .iccError
                terminalTender?.lastChipRead = .failed
            } else {
                terminalTender?.emvFallbackCondition = .emptyCandidateList
                terminalTender?.lastChipRead = .successful
            }
            terminalTender?.cardDataSource = .fallbackSwipe
        } else {
            terminalTender?.cardDataSource =
                IngenicoMoby5500DeviceManager.cardDataSourceType(entryMode)
            terminalTender?.lastChipRead = .successful
        }

        terminalTender?.tlvData               = tlvData
        terminalTender?.formatID              = resp[NSNumber(value: RUAParameter.formatID.rawValue)] as? String
        terminalTender?.encryptedTrackData    = resp[NSNumber(value: RUAParameter.encryptedTrack.rawValue)] as? String
        terminalTender?.track1Data            = resp[NSNumber(value: RUAParameter.track1Data.rawValue)] as? String
        terminalTender?.track2Data            = resp[NSNumber(value: RUAParameter.track2Data.rawValue)] as? String
        terminalTender?.packEncryptedTrackData = packEncryptedTrackData
        terminalTender?.ksn                   = resp[NSNumber(value: 353)] as? String
        terminalTender?.cardHolderName        = resp[NSNumber(value: RUAParameter.cardHolderName.rawValue)] as? String
        terminalTender?.expirationDate        = resp[NSNumber(value: RUAParameter.cardExpDate.rawValue)] as? String
        terminalTender?.cardholderAuthenticationMethod =
            TerminalTender.cardholderAuthenticationMethodfromTlv(cvmResult)
        terminalTender?.redactedPan           = resp[NSNumber(value: RUAParameter.redactedCardNumber.rawValue)] as? String
        terminalTender?.maskedPan             = resp[NSNumber(value: 425)] as? String
        terminalTender?.serviceCode           = resp[NSNumber(value: RUAParameter.serviceCode.rawValue)] as? String
        terminalTender?.deviceSerialNumber    = deviceSerialNumber
        terminalTender?.kernelVersionNumber   = kernelVersionNumber
    }

    func updateTransactionAfterCompleteTransactionResponse(_ response: RUAResponse) {
        let resp = response.responseData ?? [:]
        let cvmResult  = resp[NSNumber(value: RUAParameter.cardholderVerificationMethodResult.rawValue)] as? String
        let entryMode  = resp[NSNumber(value: RUAParameter.posEntryMode.rawValue)] as? String
        terminalTender?.cardDataSource =
            IngenicoMoby5500DeviceManager.cardDataSourceType(entryMode)
        terminalTender?.tlvData =
            resp[NSNumber(value: RUAParameter.emvtlvData.rawValue)] as? String
        terminalTender?.encryptedTrackData =
            resp[NSNumber(value: RUAParameter.packEncryptedTrackData.rawValue)] as? String
        terminalTender?.ksn =
            resp[NSNumber(value: 353)] as? String
        terminalTender?.cardholderAuthenticationMethod =
            TerminalTender.cardholderAuthenticationMethodfromTlv(cvmResult)
        terminalTender?.deviceSerialNumber  = deviceSerialNumber
        terminalTender?.kernelVersionNumber = kernelVersionNumber
    }
}

// MARK: - EMV Parameter Builders

extension IngenicoMoby5500DeviceManager {

    func getEMVFinalAppSelectionParameters(_ applicationIdentifier: String?) -> [NSNumber: Any] {
        var params: [NSNumber: Any] = [:]
        let key = NSNumber(value: RUAParameter.applicationIdentifier.rawValue)
        params[key] = applicationIdentifier ?? "A0000000041010"
        return params
    }

    func getMoby5500EMVTransactionDataParameters() -> [NSNumber: Any] {
        var dictionary: [NSNumber: Any] = [:]
        let jsonDict = loadDictionaryFromEMVTransactionConfigsJSON()
        if let parsed = jsonDict["RP450EMVTransactionDataParameters"] as? [String: Any] {
            for (key, value) in parsed {
                let enumKey = NSNumber(value: RUAEnumerationHelper.ruaParameter_(toEnumeration: key).rawValue)
                dictionary[enumKey] = value
            }
        }
        dictionary[NSNumber(value: RUAParameter.terminalActionCodeDefault.rawValue)] = "0000000000"
        dictionary[NSNumber(value: RUAParameter.terminalActionCodeDenial.rawValue)]  = "0000000000"
        dictionary[NSNumber(value: RUAParameter.terminalActionCodeOnline.rawValue)]  = "0000000000"
        return dictionary
    }

    private func getEMVStartTransactionParametersBase() -> [NSNumber: Any] {
        var dictionary: [NSNumber: Any] = [:]
        let jsonDict = loadDictionaryFromEMVTransactionConfigsJSON()
        if let parsed = jsonDict["RP450EMVStartTransactionParameters"] as? [String: Any] {
            for (key, value) in parsed {
                let enumKey = NSNumber(value: RUAEnumerationHelper.ruaParameter_(toEnumeration: key).rawValue)
                dictionary[enumKey] = value
            }
        }
        return dictionary
    }

    func getEMVStartTransactionParameters(_ transactionAmount: String) -> [NSNumber: Any] {
        var params = getEMVStartTransactionParametersBase()
        let posixLocale = Locale(identifier: "en_US_POSIX")

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyMMdd"
        dateFormatter.locale = posixLocale

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HHmmss"
        timeFormatter.locale = posixLocale

        let now = Date()
        let dateStr = dateFormatter.string(from: now)
        let timeStr = timeFormatter.string(from: now)
        let amount  = Int(transactionAmount) ?? 0

        params[NSNumber(value: RUAParameter.amountAuthorizedBinary.rawValue)]  = String(format: "%08X", amount)
        params[NSNumber(value: RUAParameter.amountAuthorizedNumeric.rawValue)] = String(format: "%012d", amount)
        params[NSNumber(value: RUAParameter.transactionDate.rawValue)]         = dateStr
        params[NSNumber(value: RUAParameter.transactionTime.rawValue)]         = timeStr

        consoleLog("EMVStartTransactionParameters:")
        for (key, value) in params {
            consoleLog("\(key.intValue) : \(value)")
        }
        return params
    }

    private func getEMVTransactionDataParametersBase() -> [NSNumber: Any] {
        var dictionary: [NSNumber: Any] = [:]
        let jsonDict = loadDictionaryFromEMVTransactionConfigsJSON()
        if let parsed = jsonDict["RP450EMVTransactionDataParameters"] as? [String: Any] {
            for (key, value) in parsed {
                let enumKey = NSNumber(value: RUAEnumerationHelper.ruaParameter_(toEnumeration: key).rawValue)
                dictionary[enumKey] = value
            }
        }
        return dictionary
    }

    func getEMVTransactionDataParameters(_ aidValue: String?) -> [NSNumber: Any] {
        var params = getEMVTransactionDataParametersBase()
        let tac = getTerminalActionCodes()
        for (key, value) in tac {
            if let aidValue = aidValue, aidValue.contains(key),
               let tacDict = value as? [String: Any] {
                if let v = tacDict["TerminalActionCodeDefault"] {
                    params[NSNumber(value: RUAParameter.terminalActionCodeDefault.rawValue)] = v
                }
                if let v = tacDict["TerminalActionCodeDenial"] {
                    params[NSNumber(value: RUAParameter.terminalActionCodeDenial.rawValue)] = v
                }
                if let v = tacDict["TerminalActionCodeOnline"] {
                    params[NSNumber(value: RUAParameter.terminalActionCodeOnline.rawValue)] = v
                }
            }
        }
        consoleLog("EMVTransactionDataParameters:")
        for (key, value) in params {
            consoleLog("\(key.intValue) : \(value)")
        }
        return params
    }

    private func getEMVTransactionCompleteParametersBase() -> [NSNumber: Any] {
        var dictionary: [NSNumber: Any] = [:]
        let jsonDict = loadDictionaryFromEMVTransactionConfigsJSON()
        if let parsed = jsonDict["RP450EMVTransactionCompleteParameters"] as? [String: Any] {
            for (key, value) in parsed {
                let enumKey = NSNumber(value: RUAEnumerationHelper.ruaParameter_(toEnumeration: key).rawValue)
                dictionary[enumKey] = value
            }
        }
        return dictionary
    }

    func getEMVCompleteTransactionParameters() -> [NSNumber: Any] {
        let params = getEMVTransactionCompleteParametersBase()
        consoleLog("EMVCompleteTransactionParameters:")
        for (key, value) in params {
            consoleLog("\(key.intValue) : \(value)")
        }
        return params
    }

    func getTerminalActionCodes() -> [String: Any] {
        let jsonDictionary = loadDictionaryFromEMVTransactionConfigsJSON()
        return jsonDictionary["TerminalActionCode"] as? [String: Any] ?? [:]
    }
}

// MARK: - JSON / Provisioning

extension IngenicoMoby5500DeviceManager {

    @discardableResult
    func loadDictionaryFromJSON() -> [String: Any]? {
        let cloudDict = fetchAndStoreJSON()
        if cloudDict == nil {
            let fileName = debug ? "provisionTest_5500" : "provisionProd_5500"
            if debug { os_log("DEBUG PROVISION TEST WERE USED") }

            guard let bundle = Bundle(identifier: "com.heartland.Heartland-iOS-SDK"),
                  let path = bundle.path(forResource: fileName, ofType: "json"),
                  let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
                os_log("Cannot find json")
                return nil
            }
            do {
                if let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    UserDefaults.standard.set(dict, forKey: "storedJSON")
                    UserDefaults.standard.synchronize()
                    return dict
                }
            } catch {
                os_log("Cannot serialize json due to %@", error.localizedDescription)
            }
            return nil
        } else {
            UserDefaults.standard.set(cloudDict, forKey: "storedJSON")
            UserDefaults.standard.synchronize()
            return cloudDict
        }
    }

    @discardableResult
    func fetchAndStoreJSON() -> [String: Any]? {
        let urlString = debug
            ? "https://raw.githubusercontent.com/hps/Moby-5500-Config/main/provisionTest.json"
            : "https://raw.githubusercontent.com/hps/Moby-5500-Config/main/provisionProd.json"

        os_log("URL STRING USED TO FETCH JSON %@", urlString)

        guard let url = URL(string: urlString) else { return nil }
        var resultDict: [String: Any]?
        let semaphore = DispatchSemaphore(value: 0)

        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self = self else { semaphore.signal(); return }
            if let error = error {
                os_log("Error fetching JSON: %@", error.localizedDescription)
                resultDict = self.loadDictionaryFromDefaultsJSON()
                semaphore.signal()
                return
            }
            guard let data = data,
                  let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                resultDict = self.loadDictionaryFromDefaultsJSON()
                semaphore.signal()
                return
            }
            resultDict = dict
            let version = ((dict["processor_profile_config_list"] as? [Any])?.first as? [String: Any])?["dynamic_conf_cust_str_ver"] as? String
            let stored  = self.loadDictionaryFromDefaultsJSON()
            let localVersion = (stored["processor_profile_config_list"] as? [Any])
                .flatMap { ($0.first as? [String: Any])?["dynamic_conf_cust_str_ver"] as? String }

            if stored.isEmpty || localVersion == nil {
                UserDefaults.standard.set(dict, forKey: "storedJSON")
                UserDefaults.standard.synchronize()
            } else if version != localVersion {
                UserDefaults.standard.set(dict, forKey: "storedJSON")
                UserDefaults.standard.synchronize()
            } else {
                if self.debug { os_log("No updated version needed. Same version.") }
            }
            semaphore.signal()
        }.resume()

        semaphore.wait()
        return resultDict
    }

    func loadDictionaryFromDefaultsJSON() -> [String: Any] {
        (UserDefaults.standard.object(forKey: "storedJSON") as? [String: Any]) ?? [:]
    }

    func loadDictionaryFromEMVTransactionConfigsJSON() -> [String: Any] {
        (UserDefaults.standard.object(forKey: "storedEMVTransactionConfig") as? [String: Any]) ?? [:]
    }

    func loadDictionaryFromEMVTransactionConfigsJSONFromCloud() -> [String: Any]? {
        guard let url = URL(string: "https://raw.githubusercontent.com/hps/Moby-5500-Config/main/EMVConfigs.json") else { return nil }
        var resultDict: [String: Any]?
        let semaphore = DispatchSemaphore(value: 0)

        URLSession.shared.dataTask(with: url) { data, _, error in
            if let error = error {
                os_log("Error fetching JSON: %@", error.localizedDescription)
            } else if let data = data,
                      let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                resultDict = dict
            }
            semaphore.signal()
        }.resume()

        semaphore.wait()
        return resultDict
    }

    func fetchAndUpdateEMVTransactionConfigsJSON() {
        guard let cloud = loadDictionaryFromEMVTransactionConfigsJSONFromCloud() else { return }
        let cloudVersion = ((cloud["processor_profile_config_list"] as? [Any])?.first as? [String: Any])?["dynamic_conf_cust_str_ver"] as? String
        let stored       = UserDefaults.standard.object(forKey: "storedEMVTransactionConfig") as? [String: Any]

        if let stored = stored, !stored.isEmpty {
            let localVersion = ((stored["processor_profile_config_list"] as? [Any])?.first as? [String: Any])?["dynamic_conf_cust_str_ver"] as? String
            if cloudVersion != localVersion {
                UserDefaults.standard.set(cloud, forKey: "storedEMVTransactionConfig")
                UserDefaults.standard.synchronize()
            }
        } else {
            UserDefaults.standard.set(cloud, forKey: "storedEMVTransactionConfig")
            UserDefaults.standard.synchronize()
        }
    }

    func createTempFileWithJSONData(_ data: Data) -> String? {
        let path = (NSTemporaryDirectory() as NSString).appendingPathComponent("provision.json")
        (data as NSData).write(toFile: path, atomically: true)
        return path
    }

    func pushProvisionFileFromCloud() {
        let jsonDict   = loadDictionaryFromDefaultsJSON()
        guard let data = try? JSONSerialization.data(withJSONObject: jsonDict) else {
            pushProvisionFile()
            return
        }
        let tempPath = createTempFileWithJSONData(data)
        if tempPath == nil {
            pushProvisionFile()
            return
        }
        let cmgr = configManager
        cmgr?.getFirmwareVersionString(for: .dynamicConfiguration) { [weak self] response in
            guard let self = self, let response = response else { return }
            let version = response.responseData?[NSNumber(value: RUAParameter.firmwareVersionString.rawValue)] as? String
            let jsonDict = self.loadDictionaryFromDefaultsJSON()
            let jsonVersion = ((jsonDict["processor_profile_config_list"] as? [Any])?.first as? [String: Any])?["dynamic_conf_cust_str_ver"] as? String

            self.consoleLog("Reader version = '\(version ?? "")' <> json version = '\(jsonVersion ?? "")'")

            if version != jsonVersion {
                cmgr?.performJsonProvisioning(tempPath ?? "",
                    progress: { [weak self] messageType, additionalMessage in
                        self?.consoleLog("[performJsonProvisioning] \(messageType.rawValue) \(additionalMessage ?? "")")
                    },
                    response: { [weak self] provResponse in
                        guard let self = self, let provResponse = provResponse else { return }
                        if provResponse.responseCode == RUAResponseCodeSuccess {
                            self.startTransactionProcess()
                        } else {
                            cmgr?.clearAIDSList({ _, _ in }, response: { [weak self] ruaResponse in
                                guard let self = self, let ruaResponse = ruaResponse else { return }
                                self.consoleLog(self.ruaResponse(toString: ruaResponse))
                                self.clearPublicKeys()
                            })
                        }
                        self.consoleLog(self.ruaResponse(toString: provResponse))
                    }
                )
            } else {
                self.startTransactionProcess()
            }
        }
    }

    func pushProvisionFile() {
        let cmgr = configManager
        cmgr?.getFirmwareVersionString(for: .dynamicConfiguration) { [weak self] response in
            guard let self = self, let response = response else { return }
            let version = response.responseData?[NSNumber(value: RUAParameter.firmwareVersionString.rawValue)] as? String
            let jsonDict = self.loadDictionaryFromDefaultsJSON()
            let jsonVersion = ((jsonDict["processor_profile_config_list"] as? [Any])?.first as? [String: Any])?["dynamic_conf_cust_str_ver"] as? String

            self.consoleLog("Reader version = '\(version ?? "")' <> json version = '\(jsonVersion ?? "")'")

            if version != jsonVersion {
                let filename = self.debug ? "provisionTest_5500" : "provisionProd_5500"
                if self.debug { os_log("DEBUG PROVISION TEST WERE USED") }
                let jsonFilePath = Bundle.main.path(forResource: filename, ofType: "json")

                cmgr?.performJsonProvisioning(jsonFilePath ?? "",
                    progress: { [weak self] messageType, additionalMessage in
                        self?.consoleLog("[performJsonProvisioning] \(messageType.rawValue) \(additionalMessage ?? "")")
                    },
                    response: { [weak self] provResponse in
                        guard let self = self, let provResponse = provResponse else { return }
                        if provResponse.responseCode == RUAResponseCodeSuccess {
                            self.startTransactionProcess()
                        } else {
                            cmgr?.clearAIDSList({ _, _ in }, response: { [weak self] ruaResponse in
                                guard let self = self, let ruaResponse = ruaResponse else { return }
                                self.consoleLog(self.ruaResponse(toString: ruaResponse))
                                self.clearPublicKeys()
                            })
                        }
                        self.consoleLog(self.ruaResponse(toString: provResponse))
                    }
                )
            } else {
                self.startTransactionProcess()
            }
        }
    }
}

// MARK: - Configuration (AIDs / Public Keys / DOLs)

extension IngenicoMoby5500DeviceManager {

    func setupAIDSandPublicKeys() {
        let list = getConnectedDeviceList()
        if let sn = connectedDeviceSerialNumber, list.contains(sn) {
            initialized = true
        }
        setupExpectedDOLs()
        pushProvisionFileFromCloud()
    }

    func setupExpectedDOLs() {
        let cmgr = deviceManager?.getConfigurationManager()
        cmgr?.setExpectedAmountDOL(getAmountDolsList())
        cmgr?.setExpectedContactlessOnlineDOL(getContactlessOnlineDolsList())
        cmgr?.setExpectedContactlessResponseDOL(getContactlessResponseDolsList())
        cmgr?.setExpectedResponseDOL(getResponseDolsList())
        cmgr?.setExpectedOnlineDOL(getOnlineDolsList())
    }

    func clearPublicKeys() {
        let cmgr = configManager
        cmgr?.clearPublicKeys({ _, _ in }, response: { [weak self] ruaResponse in
            guard let self = self, let ruaResponse = ruaResponse else { return }
            self.consoleLog(self.ruaResponse(toString: ruaResponse))
            self.submitAIDs()
        })
    }

    func submitAIDs() {
        let cmgr = configManager
        cmgr?.submitAIDList(getAIDsList(),
            progress: { _, _ in },
            response: { [weak self] ruaResponse in
                guard let self = self, let ruaResponse = ruaResponse else { return }
                self.consoleLog(self.ruaResponse(toString: ruaResponse))
                self.submitContactlessAIDs()
            }
        )
    }

    func submitContactlessAIDs() {
        let cmgr = configManager
        cmgr?.submitContactlessAIDList(getContactlessAIDsList(),
            progress: { _, _ in },
            response: { [weak self] ruaResponse in
                guard let self = self, let ruaResponse = ruaResponse else { return }
                self.consoleLog(self.ruaResponse(toString: ruaResponse))
                self.submitPublicKeys()
            }
        )
    }

    func submitPublicKeys() {
        let cmgr = configManager
        let keys = getPublicKeysList()
        guard currentPublicKeyIndex < keys.count else { return }
        cmgr?.submitPublicKey(keys[currentPublicKeyIndex],
            progress: { _, _ in },
            response: { [weak self] ruaResponse in
                guard let self = self, let ruaResponse = ruaResponse else { return }
                self.consoleLog(self.ruaResponse(toString: ruaResponse))
                self.currentPublicKeyIndex += 1
                if self.currentPublicKeyIndex < self.getPublicKeysList().count {
                    self.submitPublicKeys()
                } else {
                    self.setupOnlineDOL()
                }
            }
        )
    }

    func setupOnlineDOL() {
        let cmgr = configManager
        cmgr?.setOnlineDOL(getOnlineDolsList(),
            progress: { _, _ in },
            response: { [weak self] ruaResponse in
                guard let self = self, let ruaResponse = ruaResponse else { return }
                self.consoleLog(self.ruaResponse(toString: ruaResponse))
                self.setupResponseDOL()
            }
        )
    }

    func setupResponseDOL() {
        let cmgr = configManager
        cmgr?.setResponseDOL(getResponseDolsList(),
            progress: { _, _ in },
            response: { [weak self] ruaResponse in
                guard let self = self, let ruaResponse = ruaResponse else { return }
                self.consoleLog(self.ruaResponse(toString: ruaResponse))
                self.setupDOLs()
            }
        )
    }

    func setupDOLs() {
        let cmgr = configManager
        cmgr?.setAmountDOL(getAmountDolsList(),
            progress: { _, _ in },
            response: { [weak self] ruaResponse in
                guard let self = self, let ruaResponse = ruaResponse else { return }
                self.consoleLog(self.ruaResponse(toString: ruaResponse))
                self.setupContactlessOnlineDOL()
            }
        )
    }

    func setupContactlessOnlineDOL() {
        let cmgr = configManager
        cmgr?.setContactlessOnlineDOL(getContactlessOnlineDolsList(),
            progress: { _, _ in },
            response: { [weak self] ruaResponse in
                guard let self = self, let ruaResponse = ruaResponse else { return }
                self.consoleLog(self.ruaResponse(toString: ruaResponse))
                self.setupContactlessResponseDOL()
            }
        )
    }

    func setupContactlessResponseDOL() {
        let cmgr = configManager
        cmgr?.setContactlessResponseDOL(getContactlessResponseDolsList(),
            progress: { _, _ in },
            response: { [weak self] ruaResponse in
                guard let self = self, let ruaResponse = ruaResponse else { return }
                self.consoleLog(self.ruaResponse(toString: ruaResponse))
                if ruaResponse.responseCode == RUAResponseCodeSuccess {
                    self.configureContactlessTransactionOptions()
                }
            }
        )
    }

    func configureContactlessTransactionOptions() {
        let cmgr = configManager
        cmgr?.configureContactlessTransactionOptions(
            true,
            supportAMEX: true,
            enableCryptogram17: true,
            enableOnlineCryptogram: true,
            enableOnline: true,
            enableMagStripe: false,
            enableMagChip: true,
            enableQVSDC: true,
            enableMSD: false,
            contactlessOutcomeDisplayTime: 1
        ) { [weak self] ruaResponse in
            guard let self = self, let ruaResponse = ruaResponse else { return }
            self.consoleLog(self.ruaResponse(toString: ruaResponse))
            if ruaResponse.responseCode == RUAResponseCodeSuccess {
                self.setFirmwareVersion()
            }
        }
    }

    func setFirmwareVersion() {
        let jsonDict    = loadDictionaryFromDefaultsJSON()
        let jsonVersion = ((jsonDict["processor_profile_config_list"] as? [Any])?.first as? [String: Any])?["dynamic_conf_cust_str_ver"] as? String

        configManager?.setFirmwareType(.dynamicConfiguration,
                                       withVersion: jsonVersion ?? "") { [weak self] response in
            guard let self = self, let response = response else { return }
            self.consoleLog(self.ruaResponse(toString: response))
        }
        setupExpectedDOLs()
        startTransactionProcess()
    }

    func deviceConfigurationComplete(_ response: RUAResponse?) {
        if response == nil || response?.responseCode == RUAResponseCodeSuccess {
            if let sn = connectedDeviceSerialNumber {
                configuredDevices.insert(sn)
            }
            saveConfiguredDevices()
            delegate?.onTransactionStatus(.configurationComplete, withIngenicoResponse: nil)
        } else {
            handleRuaResponseError(response!)
        }
    }
}

// MARK: - AID / PublicKey / DOL List Builders

extension IngenicoMoby5500DeviceManager {

    func getAIDsList() -> [RUAApplicationIdentifier] {
        let jsonDict = loadDictionaryFromDefaultsJSON()
        guard let cfg   = (jsonDict["processor_profile_config_list"] as? [Any])?.first as? [String: Any],
              let aids  = cfg["aids"] as? [String: Any],
              let array = aids["contact_list"] as? [[String: Any]] else { return [] }
        return array.map {
            RUAApplicationIdentifier(
                rid: $0["rid"] as? String,
                withPIX: $0["pix"] as? String,
                withAID: nil,
                withApplicationLabel: nil,
                withTerminalApplicationVersion: $0["terminal_application_version"] as? String,
                withLowestSupportedICCApplicationVersion: $0["lowest_supported_icc_application_version"] as? String,
                withPriorityIndex: $0["priority_index"] as? String,
                withApplicationSelectionFlags: $0["application_selection_flags"] as? String
            )
        }
    }

    func getContactlessAIDsList() -> [RUAApplicationIdentifier] {
        let jsonDict = loadDictionaryFromDefaultsJSON()
        guard let cfg   = (jsonDict["processor_profile_config_list"] as? [Any])?.first as? [String: Any],
              let aids  = cfg["aids"] as? [String: Any],
              let array = aids["contactless_list"] as? [[String: Any]] else { return [] }
        return array.map {
            RUAApplicationIdentifier(
                rid: $0["rid"] as? String,
                withPIX: $0["pix"] as? String,
                withAID: $0["aid"] as? String,
                withApplicationLabel: nil,
                withTerminalApplicationVersion: $0["terminal_application_version"] as? String,
                withLowestSupportedICCApplicationVersion: $0["lowest_supported_icc_application_version"] as? String,
                withPriorityIndex: $0["priority_index"] as? String,
                withApplicationSelectionFlags: $0["application_selection_flags"] as? String,
                withCVMLimit: $0["cvm_limit"] as? String,
                withFloorLimit: $0["floor_limit"] as? String,
                withTLVData: $0["tlv_data"] as? String,
                withTermCaps: $0["term_caps"] as? String,
                withTxnLimit: $0["txn_limit"] as? String
            )
        }
    }

    func getPublicKeysList() -> [RUAPublicKey] {
        let jsonDict = loadDictionaryFromDefaultsJSON()
        guard let cfg   = (jsonDict["processor_profile_config_list"] as? [Any])?.first as? [String: Any],
              let array = cfg["public_keys"] as? [[String: Any]] else { return [] }
        return array.map {
            RUAPublicKey(
                rid: $0["rid"] as? String,
                withCAPublicKeyIndex: $0["ca_public_key_index"] as? String,
                withPublicKey: $0["public_key"] as? String,
                withExponentOfPublicKey: $0["exponent_of_public_key"] as? String,
                withChecksum: $0["checksum"] as? String
            )
        }
    }

    func getAmountDolsList() -> [NSNumber] {
        dolsList("Amount")
    }

    func getOnlineDolsList() -> [NSNumber] {
        dolsList("Online")
    }

    func getResponseDolsList() -> [NSNumber] {
        dolsList("dols")
    }

    func getContactlessResponseDolsList() -> [NSNumber] {
        dolsList("ContactlessResponse")
    }

    func getContactlessOnlineDolsList() -> [NSNumber] {
        dolsList("ContactlessOnline")
    }

    private func dolsList(_ key: String) -> [NSNumber] {
        let json = loadDictionaryFromDefaultsJSON()
        guard let cfg   = (json["processor_profile_config_list"] as? [Any])?.first as? [String: Any],
              let dols  = cfg["dols"] as? [String: Any],
              let names = dols[key] as? [String] else { return [] }
        return names.map { NSNumber(value: RUAEnumerationHelper.ruaParameter_(toEnumeration: $0).rawValue) }
    }
}

// MARK: - Device History / Persistence

extension IngenicoMoby5500DeviceManager {

    func savePairedDevices() {
        let archiveArray: [Data] = pairedDevices.compactMap {
            try? NSKeyedArchiver.archivedData(withRootObject: $0, requiringSecureCoding: false)
        }
        UserDefaults.standard.set(archiveArray, forKey: pairedDeviceKey)
        UserDefaults.standard.synchronize()
        pairedDevices.removeAll()
    }

    func saveConfiguredDevices() {
        let archiveArray: [Data] = configuredDevices.compactMap {
            try? NSKeyedArchiver.archivedData(withRootObject: $0, requiringSecureCoding: false)
        }
        UserDefaults.standard.set(archiveArray, forKey: configuredDeviceKey)
        UserDefaults.standard.synchronize()
    }

    func pathForConnectedDeviceHistoryPlist() -> String {
        let docs = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        return (docs as NSString).appendingPathComponent("ConnectedDeviceHistory.plist")
    }

    func createConnectedDeviceHistoryPlist() {
        let path = pathForConnectedDeviceHistoryPlist()
        if !FileManager.default.fileExists(atPath: path) {
            let data: [String: Any] = [:]
            (data as NSDictionary).write(toFile: path, atomically: true)
        }
    }

    func getConnectedDeviceList() -> [String] {
        let path = pathForConnectedDeviceHistoryPlist()
        if !FileManager.default.fileExists(atPath: path) {
            createConnectedDeviceHistoryPlist()
        }
        let savedList = NSDictionary(contentsOfFile: path) as? [String: String] ?? [:]
        return Array(savedList.values)
    }

    func saveConnectedDeviceSerialNumber(_ identifier: String?) {
        guard let identifier = identifier,
              !getConnectedDeviceList().contains(identifier) else { return }
        let path = pathForConnectedDeviceHistoryPlist()
        var data = NSDictionary(contentsOfFile: path) as? [String: Any] ?? [:]
        data["\(data.count)"] = identifier
        (data as NSDictionary).write(toFile: path, atomically: true)
    }

    func saveSelectedDevice(_ ruaDevice: RUADevice) {
        if let encoded = try? NSKeyedArchiver.archivedData(withRootObject: ruaDevice, requiringSecureCoding: false) {
            UserDefaults.standard.set(encoded, forKey: "lastUsedMobyDevice")
            UserDefaults.standard.synchronize()
        }
    }

    func lastSelectedDevice() -> RUADevice? {
        guard let data = UserDefaults.standard.object(forKey: "lastUsedMobyDevice") as? Data,
              let unarchiver = try? NSKeyedUnarchiver(forReadingFrom: data) else { return nil }
        unarchiver.requiresSecureCoding = false
        return unarchiver.decodeObject(forKey: NSKeyedArchiveRootObjectKey) as? RUADevice
    }
    
    func clearSavedDevice() {
        UserDefaults.standard.removeObject(forKey: "lastUsedMobyDevice")
    }
}

// MARK: - Logging Helpers

extension IngenicoMoby5500DeviceManager {

    func ruaResponse(toString response: RUAResponse) -> String {
        var output = ""
        output += "\(RUAEnumerationHelper.ruaParameter_(toString: .command) ?? ""):\(RUAEnumerationHelper.ruaCommand_(toString: response.command) ?? ""),\n"
        output += "\(RUAEnumerationHelper.ruaParameter_(toString: .responseCode) ?? ""):\(RUAEnumerationHelper.ruaResponseCode_(toString: response.responseCode) ?? ""),\n"
        output += "\(RUAEnumerationHelper.ruaParameter_(toString: .responseType) ?? ""):\(RUAEnumerationHelper.ruaResponseType_(toString: response.responseType) ?? ""),\n"

        if response.responseCode == RUAResponseCodeError {
            output += "\(RUAEnumerationHelper.ruaParameter_(toString: .errorCode) ?? ""):\(RUAEnumerationHelper.ruaErrorCode_(toString: response.errorCode) ?? ""),\n"
            if let details = response.additionalErrorDetails {
                output += "\(RUAEnumerationHelper.ruaParameter_(toString: .errorDetails) ?? ""):\(details),\n"
            }
        }

        if let responseData = response.responseData {
            for key in responseData.keys {
                guard let keyNum = key as? NSNumber else { continue }
                let param = RUAParameter(rawValue: keyNum.intValue) ?? .command
                let value = responseData[key]
                let valueStr = value.map { "\($0)" } ?? ""
                output += "\(RUAEnumerationHelper.ruaParameter_(toString: param) ?? ""):\(valueStr),\n"
            }
        }
        return output
    }

    func logRuaParamDictionary(_ dictionary: [AnyHashable: Any]?) {
        guard let dictionary = dictionary else { return }
        var output = ""
        for key in dictionary.keys {
            guard let keyNum = key as? NSNumber else { continue }
            let param = RUAParameter(rawValue: keyNum.intValue) ?? .command
            let value = dictionary[key] as? String ?? ""
            output += "\(RUAEnumerationHelper.ruaParameter_(toString: param) ?? ""):\(value),\n"
        }
        os_log("%@", output)
    }

    func consoleLog(_ data: String?) {
        guard debug, let data = data else { return }
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm:ss"
        _ = fmt.string(from: Date())
        // NSLog("%@:%@\n", dateStr, data)  // Uncomment to enable verbose logging
    }

    func onDeviceConnected() {
        delegate?.deviceConnected()
    }
}
