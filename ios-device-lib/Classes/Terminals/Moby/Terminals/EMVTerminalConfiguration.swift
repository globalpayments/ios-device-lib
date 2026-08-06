//
//  EMVTerminalConfiguration.swift
//  ios-device-lib
//

import Foundation

@objcMembers
public class EMVTerminalConfiguration: NSObject, Codable {

    public var maxPinLength = PinLength.notSupported
    public var terminalFloorLimit: UInt = 0
    public var terminalCvmLimit: UInt = 0
    public var terminalAuthenticationCapability = TerminalAuthenticationCapability.noCapability
    public var terminalOperatingEnvironment = TerminalOperatingEnvironment.onMerchantPremisesMPOS
    public var terminalOutputCapability = TerminalOutputCapability.displayOnly
    public var terminalCapability = TerminalCapability.noTerminalManual
    public var terminalCardCaptureSupported = false
    public var encryptionType = EncryptionType.TDES

    public init(terminalType: RUATerminalType) {
        super.init()

        switch terminalType {
        case .moby3000:
            terminalCapability = .magStripeIccOnly

        default:
            break
        }
    }

    public init(terminalType: TerminalType) {
        super.init()

        maxPinLength = PinLength.notSupported
        terminalFloorLimit = 0
        terminalCvmLimit = 0

        switch terminalType {
        case .ingencio_g4x_g5x:
            terminalCapability = .magStripeReadOnly

        case .ingencio_moby3000:
            terminalCapability = .magStripeIccOnly
            
        case .ingenico_moby5500:
            terminalCapability = .iccContactContactless

        case .bbpos_c2x:
            terminalCapability = .iccContactContactless

        case .unimag:
            terminalCapability = .magStripeReadOnly

        default:
            break
        }
    }
}
