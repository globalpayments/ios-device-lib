//
//  TerminalSettingResult.swift
//  ios-device-lib
//

import Foundation

public enum TerminalSettingResult: UInt {
    case success,
         invalidTlvFormat,
         tagNotFound,
         invalidLength,
         bootLoaderNotSupported,
         tagNotAllowedToAccess,
         tagNotWrittenCorrectly,
         invalidValue
}
