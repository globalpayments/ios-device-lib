//
//  ConnectionError.swift
//  ios-device-lib
//

import Foundation

public enum ConnectionError: Error {
    case bluetoothNotSupported,
    bluetoothPermissionNotGranted,
    bluetoothDisabled,
    bluetoothConnectionLost,
    devicePoweredOff,
    terminalNotConfigured,
    bluetoothConnectionTimeout,
    alreadyPairedWithAnotherDevice
}

