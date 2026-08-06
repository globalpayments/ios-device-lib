//
//  TerminalSettingsUpdateDelegate.swift
//  ios-device-lib
//

import Foundation

public protocol TerminalSettingsUpdateDelegate {
    func onReturnReadSetting(settingType: TerminalSettingType, value: Int?, error:Error?)
    func onReturnUpdateSetting(settingType: TerminalSettingType, result: TerminalSettingResult)
    func onError(error: ConnectionError)
}
