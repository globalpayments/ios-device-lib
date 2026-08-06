//
//  BBDeviceConstants.swift
//  ios-device-lib
//
//  Copyright (c) 2020 GlobalPayments. All rights reserved.
//

import Foundation

class BBDeviceConstants {
    /// *Quick chip*
    static let quickChipIndicator = "DF8362"
    static let quickChipIndicatorEnabled = "01"
    static let quickChipIndicatorDisabled = "00"
    
    /// *Entry Mode*
    static let entryMode = "9F39"
    static let entryModeICC = "05"
    static let entryModeManual = "06"
    static let entryModeContactlessEMVMode = "07"
    static let entryModeFallbacktoMagneticStripe = "80"
    static let entryModeFullMagneticStripeRead = "90"
    static let entryModeContactlessMagstripeMode = "91"

    // *Kernal Version - BBPOS C2X*
    static let kernalVersionBBPOSC2X = "1.1"
}
