//
//  PorticoConfig.swift
//  ios-device-lib
//

import Foundation
import GlobalPaymentsApi

public struct PorticoConfig: GatewayConfig, Equatable {
    static let OTA_SERVER_URL = "https://api.emms.bbpos.com/"
    fileprivate let TEST_ENDPOINT = "https://cert.api2.heartlandportico.com"
    fileprivate let PRODUCTION_ENDPOINT = "https://api2.heartlandportico.com"
    fileprivate let MOCK_ENDPOINT = ""

    public init() { }

    // MARK: Constants
    public var username: String = ""
    public var password: String = ""
    public var siteId: String = ""
    public var deviceId: String = ""
    public var licenseId: String = ""
    public var developerId: String = ""
    public var versionNumber: String = ""
    public var merchantName: String = ""
    public var merchantAddress: String = ""
    public var merchantNumber: String = ""
    public var signatureAgreement: String = ""
    public var acknowledgement: String = ""
    public var refundPolicy: String = ""
    public var uniqueDeviceId: String?
    public var secretApiKey: String?
    public var siteTrace: String?
    public var sdkNameVersion: String?
    
    public var serviceUrl: String {
        switch environment {
        case .production: return PRODUCTION_ENDPOINT
        case .certification: return TEST_ENDPOINT
        case .custom(let url): return url.description
        case .mock: return MOCK_ENDPOINT
        }
    }
    public var timeout: Int32?
    public var isDebug: Bool = false
    public var supportSaf: Bool = false
    public var terminalOnlineProcessTimeout: UInt?
    /// Default USD
    public var currencyCode: CurrencyCode = .USD
    /// Default USA
    public var countryCode: CountryCode = .USA

    var serviceConfig: GPServicesConfig {
        let serviceConfig = GPServicesConfig()

        serviceConfig.username = username
        serviceConfig.password = password
        serviceConfig.siteId = siteId
        serviceConfig.deviceId = deviceId
        serviceConfig.licenseId = licenseId
        serviceConfig.developerId = developerId
        serviceConfig.versionNumber = versionNumber
        serviceConfig.sdkNameVersion = sdkNameVersion

        if let uniqueDeviceId = uniqueDeviceId, !uniqueDeviceId.isEmpty {
            serviceConfig.uniqueDeviceId = uniqueDeviceId
        }

        if let secretApiKey = secretApiKey, !secretApiKey.isEmpty {
            serviceConfig.secretApiKey = secretApiKey
        }

        if let siteTrace = siteTrace, !siteTrace.isEmpty {
            serviceConfig.siteTrace = siteTrace
        }

        serviceConfig.serviceUrl = serviceUrl

        serviceConfig.timeout = timeout ?? 90

        return serviceConfig
    }

    // MARK: GatewayConfig Protocol
    public var environment: GatewayEnvironment = .production
    public var supportedTerminals: Terminals = [.none: TerminalConfig(terminalType: .none,
                                                                      autoConnect: false,
                                                                      gatewayType: .Portico,
                                                                      contactAIDs: nil,
                                                                      contactLessAIDs: nil,
                                                                      entryModes: [.manual],
                                                                      timeout: 120,
                                                                      emvTerminalConfig: nil),
                                                .bbpos_c2x: TerminalConfig(terminalType: .bbpos_c2x,
                                                                           autoConnect: false,
                                                                           gatewayType: .Portico,
                                                                           contactAIDs: nil,
                                                                           contactLessAIDs: nil,
                                                                           entryModes: [.contact, .contactless, .msr, .chipFallback, .quickChip],
                                                                           timeout: 120,
                                                                           emvTerminalConfig: nil,
                                                                           otaServerUrl: OTA_SERVER_URL,
                                                                           supportsOTAUpdate: true),
                                                .bbpos_wisecube: TerminalConfig(terminalType: .bbpos_wisecube,
                                                                                autoConnect: false,
                                                                                gatewayType: .Portico,
                                                                                contactAIDs: nil,
                                                                                contactLessAIDs: nil,
                                                                                entryModes: [.quickChip, .contact, .contactless],
                                                                                timeout: 120,
                                                                                emvTerminalConfig: nil,
                                                                                otaServerUrl: OTA_SERVER_URL,
                                                                                supportsOTAUpdate: true),
                                                .ingenico_moby5500: TerminalConfig(terminalType: .ingenico_moby5500,
                                                                           autoConnect: false,
                                                                           gatewayType: .Portico,
                                                                           contactAIDs: nil,
                                                                           contactLessAIDs: nil,
                                                                           entryModes: [.contact, .contactless, .msr, .chipFallback, .quickChip],
                                                                           timeout: 120,
                                                                           emvTerminalConfig: nil,
                                                                           otaServerUrl: OTA_SERVER_URL,
                                                                           supportsOTAUpdate: true)
    ]
    public var terminalType: TerminalType = .none

    // MARK: Initializers

    /// Required Params to initiate Portico Gateway
    /// - Parameters:
    ///   - username: User name (Nonnull String value)
    ///   - password: Password (Nonnull String value)
    ///   - siteId: Site Id, merchent used to register (Nonnull String value)
    ///   - deviceId: Device Id (Nonnull String value)
    ///   - licenseId: LicenseId (Nonnull String value)
    ///   - environment: GatewayEnvironment (Enum)
    public init?(username: String,
                 password: String,
                 siteId: String,
                 deviceId: String,
                 licenseId: String,
                 developerId: String,
                 versionNumber: String,
                 merchantName: String,
                 merchantAddress: String,
                 merchantNumber: String,
                 signatureAgreement: String,
                 acknowledgement: String,
                 refundPolicy: String,
                 environment: GatewayEnvironment,
                 sdkNameVersion: String) {
        self.username = username
        self.password = password
        self.siteId = siteId
        self.deviceId = deviceId
        self.licenseId = licenseId
        self.developerId = developerId
        self.versionNumber = versionNumber
        self.merchantName = merchantName
        self.merchantAddress = merchantAddress
        self.merchantNumber = merchantNumber
        self.signatureAgreement = signatureAgreement
        self.acknowledgement = acknowledgement
        self.refundPolicy = refundPolicy
        self.environment = environment
        self.sdkNameVersion = sdkNameVersion

        do { try validate() }
        catch { return nil }
    }

    /// Required Params to initiate Portico Gateway
    /// - Parameters:
    ///   - secretApiKey: Secret Api Key (Nonnull String value)
    ///   - environment: GatewayEnvironment (Enum)
    public init(_ secretApiKey: String,
                merchantName: String,
                merchantAddress: String,
                merchantNumber: String,
                signatureAgreement: String,
                acknowledgement: String,
                refundPolicy: String,
                environment: GatewayEnvironment) {
        self.secretApiKey = secretApiKey
        self.merchantName = merchantName
        self.merchantAddress = merchantAddress
        self.merchantNumber = merchantNumber
        self.signatureAgreement = signatureAgreement
        self.acknowledgement = acknowledgement
        self.refundPolicy = refundPolicy
        self.environment = environment
    }
}

extension PorticoConfig: _GatewayConfig {

    @discardableResult
    internal func validate(withoutThrowing doNotThrow: Bool = false) throws -> Bool {
        // check if any required fields are empty
        if [username, password, siteId, deviceId, licenseId, developerId, versionNumber, merchantName, merchantAddress, merchantNumber]
            .reduce(false, { $0 || $1.isEmpty }) {
            print("Required fields missing")
            if doNotThrow {
                // TODO: Custom error handling
                return false
            }
            throw GatewayConfigError.missingValues
        }

        return true
    }

    internal enum CodingKeys: String, KeyPathMapping {
        case username
        case password
        case siteId
        case deviceId
        case licenseId
        case developerId
        case versionNumber
        case merchantName
        case merchantAddress
        case merchantNumber
        case signatureAgreement
        case acknowledgement
        case refundPolicy
        case uniqueDeviceId
        case secretApiKey
        case siteTrace
        case timeout
        case terminalOnlineProcessTimeout
        case terminalType
        case environment
        case currencyCode
        case countryCode
        case sdkNameVersion

        var keyPath: AnyKeyPath {
            switch self {
            // if these can be programatically generated we
            // should do that instead of having this getter
            case .username: return \PorticoConfig.username
            case .password: return \PorticoConfig.password
            case .siteId: return \PorticoConfig.siteId
            case .deviceId: return \PorticoConfig.deviceId
            case .licenseId: return \PorticoConfig.licenseId
            case .developerId: return \PorticoConfig.developerId
            case .versionNumber: return \PorticoConfig.versionNumber
            case .merchantName: return \PorticoConfig.merchantName
            case .merchantAddress: return \PorticoConfig.merchantAddress
            case .merchantNumber: return \PorticoConfig.merchantNumber
            case .signatureAgreement: return \PorticoConfig.signatureAgreement
            case .acknowledgement: return \PorticoConfig.acknowledgement
            case .refundPolicy: return \PorticoConfig.refundPolicy
            case .uniqueDeviceId: return \PorticoConfig.uniqueDeviceId
            case .secretApiKey: return \PorticoConfig.secretApiKey
            case .siteTrace: return \PorticoConfig.siteTrace
            case .timeout: return \PorticoConfig.timeout
            case .terminalOnlineProcessTimeout: return \PorticoConfig.terminalOnlineProcessTimeout
            case .terminalType: return \PorticoConfig.terminalType
            case .environment: return \PorticoConfig.environment
            case .countryCode: return \PorticoConfig.countryCode
            case .currencyCode: return \PorticoConfig.currencyCode
            case .sdkNameVersion: return \PorticoConfig.sdkNameVersion
            }
        }
    }
}
