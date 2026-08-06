//
//  IngenicoTerminal.swift
//  ios-device-lib
//

import Foundation
import os

@objcMembers
public class Device: NSObject {

    public var name: String = ""
    public var identifier: String = ""

    public init(withName name: String,
                identifier: String) {
        self.name = name
        self.identifier = identifier
    }
}
@objcMembers
class IngenicoTerminal: NSObject, Terminal, IngenicoDeviceManagerDelegate {
    

    @available(iOS 12.0, *)
    private static let log = OSLog(subsystem: "com.globalpayments.terminal.roam", category: OSLog.Category.pointsOfInterest)

    // MARK: Variables
    private var transactionFlowStep = TransactionFlowStep.idle
    private var selectedTerminal: TerminalInfo?
    private var ingenicoDeviceManager: IngenicoMethods?
//    private var ingenicoMoby5500DeviceManager: IngenicoMoby5500DeviceManager?
    private var ruaTerminal: RUATerminalType = .unknown
    private var terminalTender: TerminalTender?
    var terminalType: TerminalType
    var terminalConfig: TerminalConfig
    var searchDelegate: SearchDelegate?
    var transactionDelegate: TerminalTransactionDelegate?
    var connectionDelegate: ConnectionDelegate?
    var entryModes: [EntryMode] = EntryMode.allCases
    var cardEntryMode = EntryMode.manual
    var amount: Decimal?
    var transactionType: TransactionType = .Sale
    var connected: Bool {
        guard let terminalInfo = selectedTerminal else {
            return false
        }
        return terminalInfo.connected
    }
    var onlineTlv: String? = nil
    var reversalTlv: String? = nil
    var terminalOTAState: TerminalOTAState?
    var otaDelegate: TerminalOTAManagerDelegate?
    var authType: AuthType = .unknown

    // MARK: Init
    required init?(terminal: TerminalType, config: TerminalConfig) {
        terminalType = terminal
        terminalConfig = config

        super.init()
    }

    convenience init?(terminal: TerminalType, isDebug: Bool, config: TerminalConfig, connectionInterface: RUACommunicationInterface? = nil) {
        self.init(terminal: terminal, config: config)

        ruaTerminal = ruaTerminalType(terminal)

        let ruaConfig = RUATerminalConfig(isDebug: isDebug,
                                          isProduction: !isDebug,
                                          terminal: ruaTerminal,
                                          emvConfig: config.emvTerminalConfig,
                                          connectionInterface: connectionInterface)
        
        switch terminalType {
        case .ingenico_moby5500:
           
            ingenicoDeviceManager = IngenicoMoby5500DeviceManager(config: ruaConfig,
                                                                  autoConnect: true,
                                                                  delegate: self)
        default:
            ingenicoDeviceManager = IngenicoDeviceManager(config: ruaConfig,
                                                          autoConnect: true,
                                                          delegate: self)
        }
    }

    func search(delegate: SearchDelegate) {
        searchDelegate = delegate

        // Return terminal
        if terminalType == .ingencio_g4x_g5x {
            selectedTerminal = GMSTerminalInfo(name: "RoamPay G5x/G4x",
                                            description: "RoamPay G5x/G4x",
                                            connected: false,
                                            terminalType: .ingencio_g4x_g5x,
                                            identifier: UUID())

            searchDelegate?.deviceFound(terminalInfo: selectedTerminal!)

            return
        }
        
        ingenicoDeviceManager?.scanForDevices()
    }

    func cancelSearch() {
        ingenicoDeviceManager?.cancelSearch()
        
    }

    func connect(terminalInfo: TerminalInfo, delegate: ConnectionDelegate) {
        searchDelegate = nil
        connectionDelegate = delegate
        selectedTerminal = terminalInfo

        if terminalType == .ingencio_g4x_g5x {
            ingenicoDeviceManager?.scanForDevices()
        } else {
            ingenicoDeviceManager?.connect(Device(withName: terminalInfo.name,
                                                  identifier: terminalInfo.identifier.uuidString))
        }
    }

    func disconnect() {
        ingenicoDeviceManager?.disconnect()
    }

    func start(amount: Decimal?,
               transactionType: TransactionType,
               entryModes: [EntryMode],
               delegate: TerminalTransactionDelegate) {
        guard transactionFlowStep != .waitingForCardRemoval else {
            delegate.onError(terminalError: .cardNotRemoved)
            return
        }

        guard !entryModes.isEmpty else {
            delegate.onError(terminalError: .invalidEntryModes)
            return
        }

        transactionDelegate = delegate
        self.amount = amount
        self.transactionType = transactionType
        self.entryModes = entryModes
        transactionFlowStep = .waitingForCard

        terminalTender = TerminalTender()
        terminalTender?.transactionType = terminalTransactionType(transactionType)

        if let transactionAmount = amount {
            terminalTender?.amount = transactionAmount.penniesValue
        }

        if !entryModes.contains(.contact) {
            terminalTender?.disableEMV = true
        }

        if entryModes.contains(.quickChip) {
            terminalTender?.enableQuickChip = true
        }
        
        ingenicoDeviceManager?.startWithTender(terminalTender!)
    }

    func confirm(amount: Decimal) {
        ingenicoDeviceManager?.confirmAmount(amount == self.amount ? true : false)
    }

    func select(aid: AID) {
        ingenicoDeviceManager?.selectedAID(aid)
    }

    func sendOnlineProcessingResult(response: HostProcessingResult) {
       
        transactionFlowStep = .finishing
        let hostResponse = HostTenderResponse()
        hostResponse.transactionStatus = response.transactionState
        hostResponse.tender = terminalTender

        if let authCode = response.gatewayAuthCode {
            hostResponse.gatewayAuthCode = authCode
        }

        if let emvIsserAuthData = response.emvIssuerAuthenticationData {
            hostResponse.emvIssuerAuthenticationData = emvIsserAuthData
        }

        if let emvResponse = response.emvIssuerResponse {
            hostResponse.emvIssuerResponse = emvResponse
        }

        /**
         DF39 : Result of Online Process
         0x01 = 30Online completed (approved or rejected by the host).  The tag ì8Aî must be set to the value from the host.
         0x02 = 30Unable to go online (comms failure, or declined by merchant)
         0x00 = 30ICC referral processed offline, in the case of an ICC-initiated referral, after an auth code has been obtained.  The tag ì8Aî will be set by the EMVL2 kernel.
         */
        hostResponse.onlineProcessResult = "01"

        if let issuerAuthCode = response.emvIssuerAuthCode {
            if issuerAuthCode == "8A025A33" {
                hostResponse.onlineProcessResult = "02"
            }

            hostResponse.emvIssuerAuthCode = issuerAuthCode.starts(with: "8A02") ?
                String(issuerAuthCode.suffix(4)) :
                issuerAuthCode
        }

        if let scripts = response.emvIssuerScripts {
            hostResponse.emvIssuerScripts = scripts
        }
        
        ingenicoDeviceManager?.sendOnlineProcessingResult(hostResponse)
    }

    func cancelTransaction() {
        switch transactionFlowStep {
        case .idle, .finishing:
            break
        case .waitingForAmount,
             .startEmv,
             .setAmount,
             .selectAid,
             .waitingForCard,
             .waitingForCardRemoval:
            
            ingenicoDeviceManager?.cancelTransaction()
            
        case .confirmAmount:
            ingenicoDeviceManager?.confirmAmount(false)
            
        case .onlineProcesssing:
            let cardEntryModes: [EntryMode] =  [.msr, .chipFallback]
            guard !cardEntryModes.contains(cardEntryMode) else { return }
            
            ingenicoDeviceManager?.cancelTransaction()
            
        default:
            break
        }
    }

    // MARK: IngenicoDeviceManagerDelegate
    func devicesFound(_ devices: [Device]?) {
        devices?.forEach({ (device) in
            
            let terminal = GMSTerminalInfo(name: device.name,
                                        description: device.name,
                                        connected: false,
                                        terminalType: terminalType,
                                        identifier: UUID(uuidString: device.identifier) ?? UUID())

            searchDelegate?.deviceFound(terminalInfo: terminal)
        })
        
        searchDelegate?.onSearchComplete()
    }

    func deviceError(_ error: Error) {
        connectionDelegate?.onError(error: .bluetoothConnectionTimeout)
    }

    func deviceConnected() {
        guard var terminalInfo = selectedTerminal as? InternalTerminalInfo else {
            return
        }

        terminalInfo.setConnected(true)
        selectedTerminal = terminalInfo
        connectionDelegate?.onConnected(terminalInfo: terminalInfo)
    }

    func deviceDisconnected() {
        guard var terminalInfo = selectedTerminal as? InternalTerminalInfo else {
            return
        }

        terminalInfo.setConnected(false)
        selectedTerminal = terminalInfo
        connectionDelegate?.onDisconnected(terminalInfo: terminalInfo)
    }

    func selectAid(_ aids: [AID]?) {
        transactionFlowStep = .selectAid
        if let aid = aids {
            transactionDelegate?.requestAIDSelection(aids: aid)
        }
    }

    func onTransactionStatus(_ status: ProgressMessage,
                             withIngenicoResponse response: TerminalTender?) {
        

        var transactionStatus = TransactionState.unknown

        switch status {
        case .confirmAmount:
            amount = terminalTender?.amount.decimalValue


            transactionStatus = .waitingForAmountConfirmation
            transactionFlowStep = .confirmAmount
            transactionDelegate?.requestAmountConfirmation(amount: terminalTender?.amount.decimalValue)
            return
        case .goOnlineRequested:

            transactionFlowStep = .onlineProcesssing
            transactionStatus = .requestingOnlineProcessing

            guard let tenderData = terminalTender,
                  let cardData = createCardData(tender: tenderData) else {
                transactionDelegate?.onError(terminalError: .transactionFailed(message: "Missing Card Data"))
                return
            }
            
            transactionDelegate?.requestOnlineProcessing(cardData: cardData, isSurcharge: false)
            return
        case .reversalRequested:
            transactionStatus = .reversalInProgress
            reversalTlv = onlineTlv != nil ? onlineTlv : terminalTender?.tlvData
            transactionDelegate?.requestReversal(tlv: reversalTlv)
            transactionDelegate?.onICCTransactionComplete(result: .reversalRequired,
                                                          tlv: reversalTlv)
            return
        case .configurationComplete:
            connectionDelegate?.configuringTerminal(state: .ready)
            return
        case .presentCard:
            transactionStatus = .presentCard
            transactionFlowStep = .waitingForCard
            break
        case .insertCard, .reinsertCard, .magCardDataInsertCard:
            transactionStatus = .insertCard
            transactionFlowStep = .waitingForCard
            break
        case .completeCardRemove, .removeCard:
            transactionStatus = .removeCard
            transactionFlowStep = .finishing
            break
        case .cardErrorRemoveCard:
            transactionStatus = .removeCard
            transactionFlowStep = .waitingForCardRemoval
            break
        case .swipeDetected, .cardInserted, .tapDetected:
            transactionStatus = .cardDetected
            break
        case .waitingForCardSwipe:
            transactionStatus = .useMagstripe
            transactionFlowStep = .waitingForCard
            break
        case .waitingForDevice, .deviceBusy:
            transactionStatus = .waitingForTerminal
            break
        case .decodingStarted:
            transactionStatus = .pleaseWait
            break
        case .iccErrorSwipeCard:
            transactionStatus = .useMagstripe
            transactionFlowStep = .waitingForCard
            break
        case .swipeErrorReswipe:
            transactionStatus = .swipeErrorReSwipe
            transactionFlowStep = .waitingForCard
            break
        case .cardReadError, .errorReadingContactlessCard:
            transactionStatus = .insertSwipeOrTryAnotherCard
            transactionFlowStep = .waitingForCard
            break
        case .multipleContactlessCardsDetected:
            transactionStatus = .multipleCardDetected
            break
        case .swipeErrorReswipeMagStripe:
            transactionStatus = .swipeErrorReSwipe
            transactionFlowStep = .waitingForCard
            break
        case .updatingFirmware:
            transactionStatus = .waitingForConfiguration
            break
        case .contactlessCardStillInField:
            transactionStatus = .contactlessCardStillInField
            break
        case .pleaseSeePhone:
            transactionStatus = .pleaseSeePhone
            break
        case .contactlessInterfaceFailedTryContact:
            transactionStatus = .insertOrSwipeCard
            transactionFlowStep = .waitingForCard
            break
        case .presentCardAgain:
            transactionStatus = .presentCard
            transactionFlowStep = .waitingForCard
            break
        case .cardRemoved, .completeRemoveCard:
            transactionStatus = .cardRemoved
            break
        case .cardBlocked:
            transactionStatus = .cardBlocked
            break
        case .notAuthorized, .notAccepted:
            transactionStatus = .notAuthorized
            break
        case .insertOrSwipeCard:
            transactionStatus = .insertOrSwipeCard
            transactionFlowStep = .waitingForCard
            break
        case .transactionVoid:
            transactionStatus = .reversal
            break
        case .cardReadOkRemoveCard, .cancelledRemoveCard, .transactionVoidRemoveCard:
            transactionStatus = .removeCard
            break
        case .processingTransaction, .authorizing:
            transactionStatus = .processing
            break
        case .cardHolderBypassedPIN:
            transactionStatus = .cardHolderBypassedPIN
            break
        case .processingDoNotRemoveCard:
            transactionStatus = .processingDoNotRemoveCard
            break
        case .notAcceptedRemoveCard:
            transactionStatus = .notAcceptedRemoveCard
            break
        case .cardError:
            transactionStatus = .cardReadError
            break
        case .cancelled:
            transactionStatus = .cancelled
            break
        case .complete, .postAuthChipDecline:
            transactionStatus = .removeCard
            transactionFlowStep = .finishing
            transactionDelegate?.onICCTransactionComplete(result: .success,
                                                          tlv: terminalTender?.tlvData)
            return
        case .waitingForFallbackSwipe:
            transactionStatus = .useMagstripe
            transactionFlowStep = .waitingForCard
            break
        case .waitingForFallbackChip:
            transactionStatus = .insertCard
            transactionFlowStep = .waitingForCard
            break

        case .approved:
            transactionStatus = .removeCard
            transactionFlowStep = .finishing
            break

        case .unknownAID, .unknown:
            transactionStatus = .unknown
            break
        @unknown default:
            transactionStatus = .unknown
            break
        }

        transactionDelegate?.onState(state: transactionStatus)
    }

    func onDeviceConfigurationProgress(_ completed: Int,
                                       total progressTotal: Int,
                                       isFailed: Bool) {
        if isFailed {
            connectionDelegate?.configuringTerminal(state: .configurationFailedTryAgain)
            return
        }

        connectionDelegate?.configuringTerminal(state: .configuringTerminal(completed: Int(completed),
                                                                 total: Int(progressTotal)))
    }

    func transactionError(_ error: Error) {
        transactionDelegate?.onError(terminalError: .transactionFailed(message: error.localizedDescription, errorCode: error.errorCode ?? 0))
    }

    // MARK: Internal -> Private
    private func ruaTerminalType(_ type: TerminalType) -> RUATerminalType {
        switch type {
        case .ingencio_moby3000:
            return RUATerminalType.moby3000

        case .ingencio_moby8500:
            return RUATerminalType.moby8500

        case .ingencio_rp457bt:
            return RUATerminalType.rp45BT

        case .ingencio_g4x_g5x:
            return RUATerminalType.g4x_g5x
        case .ingenico_moby5500:
            return RUATerminalType.moby5500
        default:
            return RUATerminalType.unknown
        }
    }

    private func terminalTransactionType(_ type: TransactionType) -> TerminalTransactionType {
        switch type {
        case .Auth:
            return .auth
        case .Return:
            return .return
        case .Void, .Reversal:
            return .void
        case .Capture:
            return .capture
        case .Verify:
            return .verify
        case .Tokenize:
            return .tokenize
        case .BatchClose:
            return .batchClose
        case .TipAdjust:
            return .tipAdjust
        default:
            return .sale

        }
    }
}

extension IngenicoTerminal {

    func createCardData(tender: TerminalTender) -> AnyCardData? {
        
        switch tender.cardDataSource {
        case .emv:
            guard let contactCard = createContactCardData(tender: tender) else {
                return nil
            }
            cardEntryMode = .contact
            onlineTlv = contactCard.tlvData
            return AnyCardData(cardData: contactCard)

        case .emvContactless, .nfc:
            guard let contactlessCard = createContactlessCardData(tender: tender) else {
                return nil
            }
            cardEntryMode = .contactless
            onlineTlv = contactlessCard.tlvData
            return AnyCardData(cardData: contactlessCard)

        case .swipe:
            guard let msrCard = createMSRCardData(tender: tender) else {
                return nil
            }
            cardEntryMode = .msr
            return AnyCardData(cardData: msrCard)

        case .fallbackSwipe:
            guard let msrFallbackCard = createFallbackMSRCardData(tender: tender) else {
                return nil
            }
            cardEntryMode = .chipFallback
            return AnyCardData(cardData: msrFallbackCard)

        default:
            return nil
        }
    }

    func createContactCardData(tender: TerminalTender) -> ContactCardData? {
        
        
        var formatID: Int?

        if let id = tender.formatID {
            formatID = Int(id)
        }

        var newTlvString = ""

        let cleanTags: [String] = TLVGMParser.cleanTagsForGateway(tender) ?? [""]
        cleanTags.forEach { (str) in
            newTlvString.append(str)
        }
        
        newTlvString = newTlvString.replacingOccurrences(of: "(null)", with: "")
       
        return ContactCardData.cardData(cardholderName: tender.cardHolderName,
                                        encryptedTrack1: tender.encryptedTrackData,
                                        encryptedTrack2: nil,
                                        expirationDate: tender.expirationDate,
                                        formatID: formatID,
                                        ksn: tender.ksn,
                                        maskedPAN: tender.maskedPan,
                                        serialNumber: tender.deviceSerialNumber,
                                        serviceCode: Int(tender.serviceCode ?? ""),
                                        tlvData: tender.tlvData ?? "",
                                        terminalType: terminalType)
    }

    func createContactlessCardData(tender: TerminalTender) -> ContactlessCardData? {
        var formatID: Int?

        if let id = tender.formatID {
            formatID = Int(id)
        }

        var newTlvString = ""

        let cleanTags: [String] = TLVGMParser.cleanTagsForGateway(tender) ?? [""]
        cleanTags.forEach { (str) in
            newTlvString.append(str)
        }

        // TODO: (Scheduled) Complete this
       
        return ContactlessCardData.cardData(cardholderName: tender.cardHolderName,
                                            encryptedTrack1: tender.encryptedTrackData,
                                            encryptedTrack2: nil,
                                            expirationDate: tender.expirationDate,
                                            formatID: formatID,
                                            ksn: tender.ksn,
                                            maskedPAN: tender.maskedPan,
                                            serialNumber: tender.deviceSerialNumber,
                                            serviceCode: Int(tender.serviceCode ?? ""),
                                            tlvData: tender.tlvData ?? "",
                                            terminalType: terminalType)
    }

    func createMSRCardData(tender: TerminalTender) -> MSRCardData? {
       
        var formatID: Int?

        if let id = tender.formatID {
            formatID = Int(id)
        }
        
        return MSRCardData.cardData(cardholderName: tender.cardHolderName,
                                    encryptedTrack1: nil,
                                    encryptedTrack2: tender.encryptedTrackData,
                                    expirationDate: tender.expirationDate,
                                    formatID: formatID,
                                    ksn: tender.ksn,
                                    maskedPAN: tender.maskedPan,
                                    serialNumber: tender.deviceSerialNumber,
                                    serviceCode: Int(tender.serviceCode ?? ""),
                                    terminalType: terminalType)
    }

    func createFallbackMSRCardData(tender: TerminalTender) -> MSRFallbackCardData? {
        
        var formatID: Int?

        if let id = tender.formatID {
            formatID = Int(id)
        }

        return MSRFallbackCardData.cardData(cardholderName: tender.cardHolderName,
                                            encryptedTrack1: tender.encryptedTrackData,
                                            encryptedTrack2: nil,
                                            expirationDate: tender.expirationDate,
                                            formatID: formatID,
                                            ksn: tender.ksn,
                                            maskedPAN: tender.maskedPan,
                                            serialNumber: tender.deviceSerialNumber,
                                            serviceCode: Int(tender.serviceCode ?? ""),
                                            fallbackReason: tender.emvFallbackCondition,
                                            terminalType: terminalType)
    }
    
    func terminalVersionData(delegate: TerminalOTAManagerDelegate) {}
    
    func listAvailableOTAVersionsFor(type: TerminalOTAUpdateType, delegate: TerminalOTAManagerDelegate) {}
    
    func setTerminalVersionsFor(type: TerminalOTAUpdateType, versionString: String, delegate: TerminalOTAManagerDelegate) {}
    
    func startOTAUpdateProcess(type: TerminalOTAUpdateType, selectedVersion: String, delegate: TerminalOTAManagerDelegate) {}
    
    func readTerminalSetting(settingType: TerminalSettingType, delegate: TerminalSettingsUpdateDelegate) {}
    
    func updateTerminalSetting(settingType: TerminalSettingType, dol: String, delegate: TerminalSettingsUpdateDelegate) {}
    
    func confirmSurcharge(amount: Decimal) {
        fatalError("Needs implementation")
    }
    
    func isSurchargeEnabled() -> Bool {
        fatalError("Needs implementation")
    }
    
    func setSurchargeTimeOutError(isSurchargeTimeOutError: Bool, completion: @escaping (() -> Void)) {
        fatalError("Needs implementation")
    }
    
    func releaseDevice() {
        fatalError("Needs implementation")
    }
}
