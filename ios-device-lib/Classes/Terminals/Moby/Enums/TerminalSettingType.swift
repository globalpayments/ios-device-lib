//
//  TerminalSettingType.swift
//  ios-device-lib
//

import Foundation

public enum TerminalSettingType: UInt, CaseIterable {
    case normalModeTimeout, bluetoothDiscoveryTimeout, standByModeTimeout
    public var description: String {
        switch self {
        case .normalModeTimeout:      return "Normal Mode Timeout"
        case .bluetoothDiscoveryTimeout:  return "Bluetooth Discovery Timeout"
        case .standByModeTimeout:      return "StandBy Mode Timeout"
        }
    }
}
