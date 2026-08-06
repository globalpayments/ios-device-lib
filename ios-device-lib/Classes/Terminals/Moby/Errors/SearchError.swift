//
//  SearchError.swift
//  ios-device-lib
//

import Foundation

public enum SearchError: Error {
    case bluetoothNotSupported,
    bluetoothPermissionNotGranted,
    bluetoothDisabled,
    terminalNotConfigured
}
