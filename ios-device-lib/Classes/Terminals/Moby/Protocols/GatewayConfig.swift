//
//  GatewayConfig.swift
//  ios-device-lib
//

import Foundation

public enum GatewayConfigError: Error {
    case missingValues
}

public extension GatewayConfig {
    var gatewayType: GatewayType {
        switch self {
        //case is PropayConfig: return .ProPay
        case is PorticoConfig: return .Portico
        //case is TransITConfig: return .TransIT

        default: fatalError()
        }
    }
}

// we want GatewayConfig to be Equatable, but that makes it unusable as a type
// see https://stackoverflow.com/questions/42130150/swift-equatable-on-a-protocol
public protocol GatewayConfig: Codable {

    init()

    var terminalType: TerminalType { get set }
    var merchantName: String { get }
    var merchantAddress: String { get }
    var merchantNumber: String { get }
    var signatureAgreement: String { get }
    var acknowledgement: String { get }
    var refundPolicy: String { get }
    var environment: GatewayEnvironment { get set }
    var supportedTerminals: Terminals { get }
    var currencyCode: CurrencyCode { get set }
    var countryCode: CountryCode { get set }
    var supportSaf: Bool { get set }
    var signatureThresholdAmount: Decimal { get set }
    /// This is used to Set Terminal Debug Mode.
    var isDebug: Bool { get set }

    mutating func assign(values: [String: String]) throws

    typealias Terminals = [TerminalType: TerminalConfig]
    typealias ConfigurationError = GatewayEnvironment.ConfigurationError
}

/// Default implementation
extension GatewayConfig {
    public var merchantName: String { "" }
    public var merchantAddress: String { "" }
    public var merchantNumber: String { "" }
    public var signatureAgreement: String { "" }
    public var acknowledgement: String { "" }
    public var refundPolicy: String { "" }
    public var supportSaf: Bool { get { false } set {} }
    public var signatureThresholdAmount: Decimal { get { 0 } set {} }
}

/// GatewayConfig implementation details internal to SDK
internal protocol _GatewayConfig: GatewayConfig {

    associatedtype CodingKeys: KeyPathMapping

    mutating func assign(values: [String: String]) throws

    @discardableResult
    func validate(withoutThrowing: Bool) throws -> Bool
}

extension _GatewayConfig {

    public mutating func assign(values: [String: String]) throws {
        Mirror(reflecting: self).children.forEach {
            guard let propertyName = $0.label,
                  let value = values[propertyName] else { return }

            switch type(of: $0.value) {
            case is Int.Type, is Optional<Int>.Type:
                self.set(Int(value), for: propertyName)

            case is String.Type, is Optional<String>.Type:
                self.set(value, for: propertyName)

            default:
                break
            }
        }
    }

    mutating internal func set<T>(_ value: T, for key: String) {
        let rawKeyPath = CodingKeys.keyPath(for: key)
        if let kp = rawKeyPath as? WritableKeyPath<Self, T> { self[keyPath: kp] = value }
        else if let kp = rawKeyPath as? WritableKeyPath<Self, T?> { self[keyPath: kp] = value }
    }
}
