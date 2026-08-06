//
//  Terminal.swift
//  ios-device-lib
//

import Foundation

protocol Terminal {
    
    var terminalType: TerminalType { get }
    var terminalConfig: TerminalConfig { get }
    var searchDelegate: SearchDelegate? { get }
    var transactionDelegate: TerminalTransactionDelegate? { get set }
    var connectionDelegate: ConnectionDelegate? { get set }
    var connected: Bool { get }
    var terminalOTAState: TerminalOTAState? { get }
    var otaDelegate: TerminalOTAManagerDelegate? { get }
    var authType: AuthType { get set }
    
    init?(terminal: TerminalType, config: TerminalConfig)
    func search(delegate: SearchDelegate)
    func cancelSearch()
    func connect(terminalInfo: TerminalInfo, delegate: ConnectionDelegate)
    func disconnect()
    func start(amount: Decimal?, transactionType: TransactionType, entryModes: [EntryMode], delegate: TerminalTransactionDelegate)
    func confirm(amount: Decimal)
    func select(aid: AID)
    func sendOnlineProcessingResult(response: HostProcessingResult)
    func cancelTransaction()
    func releaseDevice()
    func terminalVersionData(delegate: TerminalOTAManagerDelegate)
    func listAvailableOTAVersionsFor(type: TerminalOTAUpdateType,
                                     delegate: TerminalOTAManagerDelegate)
    func setTerminalVersionsFor(type: TerminalOTAUpdateType,
                                     versionString: String,
                                     delegate: TerminalOTAManagerDelegate)
    func startOTAUpdateProcess(type:TerminalOTAUpdateType, selectedVersion: String,
                               delegate: TerminalOTAManagerDelegate)
    func readTerminalSetting(settingType: TerminalSettingType, delegate: TerminalSettingsUpdateDelegate)
    func updateTerminalSetting(settingType: TerminalSettingType, dol: String, delegate: TerminalSettingsUpdateDelegate)
    func confirmSurcharge(amount: Decimal)
    func isSurchargeEnabled() -> Bool
    func setSurchargeTimeOutError(isSurchargeTimeOutError: Bool, completion: @escaping(()->Void))
}
