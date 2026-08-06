//
//  TerminalEnums.swift
//  ios-device-lib
//

import Foundation

public enum PinLength: UInt, Codable {
    case unknown, notSupported,
    max4, max5, max6, max7, max8, max9, max10, max11, max12
}

public enum TerminalAuthenticationCapability: UInt, Codable {
    case noCapability,
    pinEntry,
    signatureAnalysis,
    signatureAnalysisInoperative,
    other,
    unknown
}

public enum TerminalOperatingEnvironment: UInt, Codable {
    case noTerminal,
    onMerchantPremisesAttended,
    onMerchantPremisesUnattended,
    offMerchantPremisesAttended,
    offMerchantPremisesUnattended,
    onCustomerPremisesUnattended,
    offMerchantPremisesMPOS,
    onMerchantPremisesMPOS,
    offMerchantPremisesCustomerPOS,
    onMerchantPremisesCustomerPOS,
    offCustomerPremisesUnattended,
    unknown,
    electronicDeliveryAmex,
    physicalDeliveryAmex
}

public enum TerminalOutputCapability: UInt, Codable {
    case none,
    printOnly,
    displayOnly,
    printAndDisplay,
    unknown
}

public enum TerminalCapability: UInt, Codable {
    case unknown,
    noTerminalManual,
    magStripeReadOnly,
    ocr,
    iccReadOnly,
    keyedEntryOnly,
    magStripeContactlessOnly,
    magStripeKeyedEntryOnly,
    magStripeIccKeyedEntryOnly,
    magStripeIccOnly,
    iccKeyedEntryOnly,
    iccContactContactless,
    iccContactlessOnly,
    otherCapabilityForMasterCard
}

public enum CardholderAuthenticationMethod: UInt, Codable {
    case notAuthenticated,
    pin,
    offlinePin,
    elcronicSignatureAnalysis,
    manualSignature,
    manualOther,
    unknown,
    systematicOther,
    eTicketEnvAmex,
    notSet
}

enum TerminalDecisionValue: UInt {
    case declined
    case approved
    case notPresent
}
