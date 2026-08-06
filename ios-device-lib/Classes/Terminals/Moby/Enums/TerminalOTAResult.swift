//
//  TerminalOTAResult.swift
//  ios-device-lib
//

import Foundation

@objc
public enum TerminalOTAResult: UInt {
    case success,
         setupError,
         batteryLowError,
         deviceCommError,
         serverCommError,
         failed,
         stopped,
         noUpdateRequired,
         invalidControllerStateError,
         inCompatibleFirmwareHex,
         incompitableConfigHex
}
